package edu.bingol.backend.auth.jwt;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiAuthenticationEntryPoint;
import edu.bingol.backend.common.RedisBreaker;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.context.SecurityContextHolder;

/** T-003: Redis kesilince devre kesici (fail-closed): kimlik konmaz, giris noktasi 503 + Retry-After yazar. */
class JwtAuthFilterBreakerTest {

    private final JwtService jwt = new JwtService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final AtomicLong now = new AtomicLong(1_000_000L);
    private final RedisBreaker breaker = new RedisBreaker(5000, now::get);
    private final JwtAuthFilter filter = new JwtAuthFilter(jwt, redis, breaker);

    JwtAuthFilterBreakerTest() {
        when(redis.opsForValue()).thenReturn(ops);
    }

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private String bearer() {
        User u = new User();
        u.setId(7L);
        u.setEmail("a@bingol.edu.tr");
        u.setRole(Role.USER);
        return "Bearer " + jwt.createAccessToken(u);
    }

    private MockHttpServletRequest request() {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/api/profile");
        req.addHeader("Authorization", bearer());
        return req;
    }

    @Test
    void redisFailureOpensTheBreakerAndNoIdentityIsSet() throws Exception {
        when(ops.multiGet(anyList())).thenThrow(new RedisConnectionFailureException("down"));
        MockHttpServletRequest req = request();

        filter.doFilter(req, new MockHttpServletResponse(), new MockFilterChain());

        assertNull(SecurityContextHolder.getContext().getAuthentication(), "fail-closed: kimlik konmamali");
        assertTrue(breaker.isOpen());
        assertNotNull(req.getAttribute(JwtAuthFilter.REDIS_UNAVAILABLE_ATTR));
    }

    @Test
    void whileOpenRedisIsNotTouchedAtAll() throws Exception {
        breaker.trip(new RuntimeException("x"));

        for (int i = 0; i < 250; i++) {
            filter.doFilter(request(), new MockHttpServletResponse(), new MockFilterChain());
        }

        verify(ops, never()).multiGet(anyList());
        verify(redis, never()).hasKey(anyString());
    }

    @Test
    void breakerClosesAfterTheWindowAndRedisIsTriedAgain() throws Exception {
        when(ops.multiGet(anyList())).thenThrow(new RedisConnectionFailureException("down"))
                .thenReturn(java.util.Arrays.asList(null, null, null, null));
        filter.doFilter(request(), new MockHttpServletResponse(), new MockFilterChain());
        assertTrue(breaker.isOpen());

        now.addAndGet(5001);
        assertFalse(breaker.isOpen());
        filter.doFilter(request(), new MockHttpServletResponse(), new MockFilterChain());

        assertNotNull(SecurityContextHolder.getContext().getAuthentication(), "Redis geri geldi: kimlik kabul");
        verify(ops, times(2)).multiGet(anyList());
    }

    @Test
    void entryPointAnswers503WithRetryAfterAndStandardEnvelope() throws Exception {
        when(ops.multiGet(anyList())).thenThrow(new RedisConnectionFailureException("down"));
        MockHttpServletRequest req = request();
        filter.doFilter(req, new MockHttpServletResponse(), new MockFilterChain());
        I18n i18n = mock(I18n.class);
        when(i18n.error(anyString(), anyString(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any()))
                .thenAnswer(i -> i.getArgument(1));
        MockHttpServletResponse res = new MockHttpServletResponse();

        new ApiAuthenticationEntryPoint(i18n).commence(req, res, new BadCredentialsException("x"));

        assertEquals(503, res.getStatus());
        assertEquals("5", res.getHeader("Retry-After"));
        assertTrue(res.getContentAsString().contains("\"code\":\"REDIS_UNAVAILABLE\""));
        assertEquals("Accept-Language", res.getHeader("Vary"));
    }

    @Test
    void serverSideRedisErrorRepliesDoNotOpenTheBreaker() {
        // WRONGTYPE vb. sunucu cevabi baglanti sorunu degildir
        assertFalse(RedisBreaker.isRedisFailure(new org.springframework.data.redis.RedisSystemException("WRONGTYPE", null)));
        assertTrue(RedisBreaker.isRedisFailure(new RedisConnectionFailureException("down")));
        assertTrue(RedisBreaker.isRedisFailure(new org.springframework.dao.QueryTimeoutException("t",
                new io.lettuce.core.RedisCommandTimeoutException("500ms"))));
        assertFalse(RedisBreaker.isRedisFailure(new IllegalStateException("is kurali")));
        assertEquals(1, breaker.retryAfterSeconds());
    }
}
