package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

/** Admin yazma uclari idempotency: tekrar, devam eden istek, anahtar yeniden kullanimi, fail-open. */
class IdempotencyFilterTest {

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final Map<String, String> store = new HashMap<>();
    private final I18n i18n = mock(I18n.class);
    private IdempotencyFilter filter;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenAnswer(i -> {
            String k = i.getArgument(0);
            if (store.containsKey(k)) {
                return false;
            }
            store.put(k, i.getArgument(1));
            return true;
        });
        when(ops.get(anyString())).thenAnswer(i -> store.get((String) i.getArgument(0)));
        org.mockito.Mockito.doAnswer(i -> {
            store.put(i.getArgument(0), i.getArgument(1));
            return null;
        }).when(ops).set(anyString(), anyString(), any(Duration.class));
        when(redis.delete(anyString())).thenAnswer(i -> store.remove((String) i.getArgument(0)) != null);
        when(i18n.msg(anyString(), any(java.util.Locale.class))).thenAnswer(i -> i.getArgument(0));
        filter = new IdempotencyFilter(redis, i18n, 60);
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(7L, null,
                List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))));
    }

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private MockHttpServletRequest req(String method, String path, String key) {
        MockHttpServletRequest r = new MockHttpServletRequest(method, path);
        if (key != null) {
            r.addHeader(IdempotencyFilter.HEADER, key);
        }
        return r;
    }

    private MockHttpServletResponse run(MockHttpServletRequest r, AtomicInteger calls, int status, String body)
            throws Exception {
        MockHttpServletResponse res = new MockHttpServletResponse();
        filter.doFilter(r, res, (rq, rs) -> {
            calls.incrementAndGet();
            var out = (jakarta.servlet.http.HttpServletResponse) rs;
            out.setStatus(status);
            out.setContentType("application/json");
            out.getOutputStream().write(body.getBytes(StandardCharsets.UTF_8));
        });
        return res;
    }

    @Test
    void secondRequestWithSameKeyReplaysFirstResultWithoutRunningAgain() throws Exception {
        AtomicInteger calls = new AtomicInteger();

        MockHttpServletResponse first = run(req("POST", "/api/admin/faq", "key-12345678"), calls, 201, "{\"id\":5}");
        MockHttpServletResponse second = run(req("POST", "/api/admin/faq", "key-12345678"), calls, 201, "{\"id\":6}");

        assertEquals(1, calls.get());
        assertEquals(201, first.getStatus());
        assertEquals("{\"id\":5}", first.getContentAsString());
        assertEquals(201, second.getStatus());
        assertEquals("{\"id\":5}", second.getContentAsString());
        assertEquals("true", second.getHeader(IdempotencyFilter.REPLAYED));
        assertNull(first.getHeader(IdempotencyFilter.REPLAYED));
    }

    @Test
    void concurrentSecondRequestGets409WithoutWaiting() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        MockHttpServletResponse[] inner = new MockHttpServletResponse[1];
        MockHttpServletResponse res = new MockHttpServletResponse();

        // Ilk istek isleniyorken (zincir icinde) ayni anahtarla ikinci istek gelir
        filter.doFilter(req("POST", "/api/admin/faq", "key-abcdefgh"), res, (rq, rs) -> {
            calls.incrementAndGet();
            try {
                inner[0] = run(req("POST", "/api/admin/faq", "key-abcdefgh"), calls, 200, "{}");
            } catch (Exception e) {
                throw new IllegalStateException(e);
            }
            ((jakarta.servlet.http.HttpServletResponse) rs).setStatus(200);
        });

        assertEquals(1, calls.get());
        assertEquals(409, inner[0].getStatus());
        assertTrue(inner[0].getContentAsString().contains("REQUEST_IN_PROGRESS"));
        assertEquals("1", inner[0].getHeader("Retry-After"));
    }

    @Test
    void failedResultReleasesKeySoItCanBeRetried() throws Exception {
        AtomicInteger calls = new AtomicInteger();

        run(req("PATCH", "/api/admin/users/3/role", "key-failing01"), calls, 400, "{\"code\":\"X\"}");
        MockHttpServletResponse retry = run(req("PATCH", "/api/admin/users/3/role", "key-failing01"), calls, 204, "");

        assertEquals(2, calls.get());
        assertEquals(204, retry.getStatus());
    }

    @Test
    void exceptionInChainReleasesKey() {
        assertThrows(IllegalStateException.class, () -> filter.doFilter(req("POST", "/api/admin/faq", "key-throw0001"),
                new MockHttpServletResponse(), (rq, rs) -> {
                    throw new IllegalStateException("boom");
                }));
        assertTrue(store.isEmpty());
    }

    @Test
    void sameKeyForDifferentRequestIs422() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        run(req("POST", "/api/admin/faq", "key-reused001"), calls, 200, "{}");

        MockHttpServletResponse other = run(req("DELETE", "/api/admin/faq/1", "key-reused001"), calls, 204, "");

        assertEquals(1, calls.get());
        assertEquals(422, other.getStatus());
        assertTrue(other.getContentAsString().contains("IDEMPOTENCY_KEY_REUSED"));
    }

    @Test
    void keyIsScopedPerAdmin() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        run(req("POST", "/api/admin/faq", "key-shared001"), calls, 200, "{}");
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(8L, null,
                List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))));

        run(req("POST", "/api/admin/faq", "key-shared001"), calls, 200, "{}");

        assertEquals(2, calls.get());
    }

    @Test
    void noHeaderMalformedKeyOrReadMethodsPassThrough() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        run(req("POST", "/api/admin/faq", null), calls, 200, "{}");
        run(req("POST", "/api/admin/faq", null), calls, 200, "{}");
        run(req("POST", "/api/admin/faq", "short"), calls, 200, "{}");
        run(req("GET", "/api/admin/users", "key-readonly01"), calls, 200, "{}");
        run(req("POST", "/api/other", "key-notadmin01"), calls, 200, "{}");

        assertEquals(5, calls.get());
        assertTrue(store.isEmpty());
    }

    @Test
    void redisDownFailsOpen() throws Exception {
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenThrow(new RuntimeException("redis down"));
        AtomicInteger calls = new AtomicInteger();

        MockHttpServletResponse res = run(req("POST", "/api/admin/faq", "key-failopen1"), calls, 201, "{\"ok\":true}");

        assertEquals(1, calls.get());
        assertEquals(201, res.getStatus());
        assertEquals("{\"ok\":true}", res.getContentAsString());
    }

    @Test
    void largeSuccessBodyIsNotStoredButStatusIsReplayed() throws Exception {
        AtomicInteger calls = new AtomicInteger();
        String big = "x".repeat(IdempotencyFilter.MAX_BODY + 10);

        MockHttpServletResponse first = run(req("POST", "/api/admin/faq", "key-bigbody01"), calls, 200, big);
        MockHttpServletResponse second = run(req("POST", "/api/admin/faq", "key-bigbody01"), calls, 200, big);

        assertEquals(1, calls.get());
        assertEquals(big, first.getContentAsString());
        assertEquals(200, second.getStatus());
        assertEquals("", second.getContentAsString());
    }
}
