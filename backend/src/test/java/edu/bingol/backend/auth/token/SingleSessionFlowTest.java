package edu.bingol.backend.auth.token;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.common.ApiAuthenticationEntryPoint;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import java.time.Clock;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.context.SecurityContextHolder;

/** SessionService + JwtService + JwtAuthFilter birlikte: bellek ici Redis ile tek cihaz kurali akisi. */
class SingleSessionFlowTest {

    private final Map<String, String> store = new HashMap<>();
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final JwtService jwt = new JwtService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final RefreshTokenService refresh = mock(RefreshTokenService.class);
    private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
    private final SessionService sessions = new SessionService(refresh, redis, jwt, Clock.systemUTC(), events);
    private final JwtAuthFilter filter = new JwtAuthFilter(jwt, redis);

    SingleSessionFlowTest() {
        when(redis.opsForValue()).thenReturn(ops);
        org.mockito.Mockito.doAnswer(i -> {
            store.put(i.getArgument(0), i.getArgument(1));
            return null;
        }).when(ops).set(anyString(), anyString(), any(Duration.class));
        when(ops.multiGet(anyList())).thenAnswer(i -> {
            List<String> out = new ArrayList<>();
            for (Object k : (List<?>) i.getArgument(0)) {
                out.add(store.get(k));
            }
            return out;
        });
    }

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private String token(String client) {
        User u = new User();
        u.setId(7L);
        u.setEmail("a@bingol.edu.tr");
        u.setRole(Role.USER);
        return jwt.createAccessToken(u, client);
    }

    private MockHttpServletRequest call(String bearer) throws Exception {
        SecurityContextHolder.clearContext();
        MockHttpServletRequest req = new MockHttpServletRequest();
        req.addHeader("Authorization", "Bearer " + bearer);
        filter.doFilter(req, new MockHttpServletResponse(), new MockFilterChain());
        return req;
    }

    private static boolean authenticated() {
        return SecurityContextHolder.getContext().getAuthentication() != null;
    }

    @Test
    void clientClaimRoundTripsAndDefaultsToWeb() {
        assertEquals("mobile", jwt.parse(token("mobile")).client());
        assertEquals("web", jwt.parse(token("web")).client());
        assertEquals("web", jwt.parse(token(null)).client());
    }

    @Test
    void newMobileLoginKillsOldMobileTokenButNotWebAndNewTokenWorksImmediately() throws Exception {
        // Ayni milisaniyeye dusen token/isaret yarisini yakalamak icin cok tekrar
        for (int i = 0; i < 300; i++) {
            store.clear();
            String oldMobile = token("mobile");
            String web = token("web");

            sessions.revokeClient(7L, "mobile", true);
            String newMobile = token("mobile"); // iptalden hemen sonra

            MockHttpServletRequest r1 = call(oldMobile);
            assertFalse(authenticated(), "eski mobil token reddedilmeli");
            assertNotNull(r1.getAttribute(JwtAuthFilter.SESSION_REPLACED_ATTR));

            MockHttpServletRequest r2 = call(newMobile);
            assertTrue(authenticated(), "yeni mobil token hemen kabul edilmeli");
            assertNull(r2.getAttribute(JwtAuthFilter.SESSION_REPLACED_ATTR));

            call(web);
            assertTrue(authenticated(), "web oturumu mobil girisle kapanmamali");
        }
    }

    @Test
    void revokeAllKillsBothClients() throws Exception {
        String mobile = token("mobile");
        String web = token("web");
        sessions.revokeAll(7L);

        call(mobile);
        assertFalse(authenticated());
        MockHttpServletRequest r = call(web);
        assertFalse(authenticated());
        assertNotNull(r.getAttribute(JwtAuthFilter.SESSION_REPLACED_ATTR));
    }

    @Test
    void revokeClientPublishesScopedEvent() {
        sessions.revokeClient(7L, "mobile", true);

        ArgumentCaptor<Object> cap = ArgumentCaptor.forClass(Object.class);
        org.mockito.Mockito.verify(events).publishEvent(cap.capture());
        SessionsRevokedEvent e = (SessionsRevokedEvent) cap.getValue();
        assertEquals("mobile", e.client());
        assertTrue(e.newLogin());
    }

    @Test
    void entryPointWritesSessionReplacedForRevokedTokenAndUnauthorizedOtherwise() throws Exception {
        I18n i18n = mock(I18n.class);
        when(i18n.error(anyString(), anyString(), any(), any())).thenAnswer(i -> i.getArgument(1));
        ApiAuthenticationEntryPoint ep = new ApiAuthenticationEntryPoint(i18n);

        MockHttpServletRequest replaced = new MockHttpServletRequest();
        replaced.setAttribute(JwtAuthFilter.SESSION_REPLACED_ATTR, Boolean.TRUE);
        MockHttpServletResponse res = new MockHttpServletResponse();
        ep.commence(replaced, res, new BadCredentialsException("x"));
        assertEquals(401, res.getStatus());
        assertTrue(res.getContentAsString().contains("\"code\":\"SESSION_REPLACED\""));

        MockHttpServletResponse plain = new MockHttpServletResponse();
        ep.commence(new MockHttpServletRequest(), plain, new BadCredentialsException("x"));
        assertTrue(plain.getContentAsString().contains("\"code\":\"UNAUTHORIZED\""));
    }
}
