package edu.bingol.backend.auth.jwt;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;

/** Cok oturum: access token'daki `sid` talebi ve tek oturum iptal isareti (`sessrev:<sid>`). */
class JwtAuthFilterSidTest {

    private final JwtService jwt = new JwtService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final JwtAuthFilter filter = new JwtAuthFilter(jwt, redis);

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private String token(String sid) {
        User u = new User();
        u.setId(7L);
        u.setEmail("a@bingol.edu.tr");
        u.setRole(Role.USER);
        return jwt.createAccessToken(u, "mobile", sid);
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
    void sidClaimRoundTripsAndOldTokensHaveNone() {
        assertEquals("abc123", jwt.parse(token("abc123")).sid());
        assertNull(jwt.parse(token(null)).sid());
        User u = new User();
        u.setId(7L);
        u.setRole(Role.USER);
        assertNull(jwt.parse(jwt.createAccessToken(u, "web")).sid());
    }

    @Test
    void revokedSidIsRejectedAsSessionReplacedAndOtherSidsKeepWorking() throws Exception {
        when(redis.opsForValue()).thenReturn(ops);
        // anahtar sirasi: suspended, rolechg, pwchg, pwchgm, sessrev:<sid>
        when(ops.multiGet(anyList())).thenAnswer(i -> {
            List<?> keys = i.getArgument(0);
            return Arrays.asList(null, null, null, null, keys.size() > 4 && "sessrev:dead".equals(keys.get(4)) ? "1" : null);
        });

        MockHttpServletRequest dead = call(token("dead"));
        assertFalse(authenticated(), "tek cihazdan cikis yapilan oturum aninda reddedilir");
        assertNotNull(dead.getAttribute(JwtAuthFilter.SESSION_REPLACED_ATTR));

        MockHttpServletRequest alive = call(token("alive"));
        assertTrue(authenticated(), "kullanicinin diger cihazi etkilenmez");
        assertEquals("alive", alive.getAttribute(JwtAuthFilter.SESSION_ID_ATTR));

        call(token(null));
        assertTrue(authenticated(), "sid'siz eski token eski yolla dogrulanir (4 anahtar)");
    }
}
