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

class JwtAuthFilterTest {

    private final JwtService jwt = new JwtService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final JwtAuthFilter filter = new JwtAuthFilter(jwt, redis);

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private String token(Role role) {
        User u = new User();
        u.setId(7L);
        u.setEmail("a@bingol.edu.tr");
        u.setRole(role);
        return jwt.createAccessToken(u);
    }

    private boolean authenticated(String bearer) throws Exception {
        SecurityContextHolder.clearContext();
        MockHttpServletRequest req = new MockHttpServletRequest();
        req.addHeader("Authorization", "Bearer " + bearer);
        filter.doFilter(req, new MockHttpServletResponse(), new MockFilterChain());
        return SecurityContextHolder.getContext().getAuthentication() != null;
    }

    @Test
    void roleChangeMarkerComparison() {
        assertFalse(JwtAuthFilter.tokenPredatesRoleChange(1000, null));
        assertTrue(JwtAuthFilter.tokenPredatesRoleChange(999, "1000"));
        // Ayni saniyede uretilen token (refresh sonrasi) kabul edilir
        assertFalse(JwtAuthFilter.tokenPredatesRoleChange(1000, "1000"));
        assertFalse(JwtAuthFilter.tokenPredatesRoleChange(1001, "1000"));
        assertFalse(JwtAuthFilter.tokenPredatesRoleChange(1000, "bozuk"));
    }

    @Test
    void tokenWithoutMarkersIsAccepted() throws Exception {
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.multiGet(anyList())).thenReturn(Arrays.asList(null, null));

        assertTrue(authenticated(token(Role.ADMIN)));
        assertEquals(List.of("ROLE_ADMIN"), SecurityContextHolder.getContext().getAuthentication().getAuthorities()
                .stream().map(Object::toString).toList());
    }

    @Test
    void suspendedUserIsRejected() throws Exception {
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.multiGet(anyList())).thenReturn(Arrays.asList("1", null));

        assertFalse(authenticated(token(Role.USER)));
    }

    @Test
    void tokenIssuedBeforeRoleChangeIsRejectedButFreshOneAccepted() throws Exception {
        String t = token(Role.ADMIN);
        long iat = jwt.parse(t).issuedAt().getEpochSecond();
        when(redis.opsForValue()).thenReturn(ops);

        when(ops.multiGet(anyList())).thenReturn(Arrays.asList(null, String.valueOf(iat + 5)));
        assertFalse(authenticated(t));

        when(ops.multiGet(anyList())).thenReturn(Arrays.asList(null, String.valueOf(iat)));
        assertTrue(authenticated(t));
    }

    @Test
    void identityCarriesIssuedAt() {
        JwtService.Identity id = jwt.parse(token(Role.USER));
        assertNotNull(id.issuedAt());
        assertNull(jwt.parse("garbage"));
    }
}
