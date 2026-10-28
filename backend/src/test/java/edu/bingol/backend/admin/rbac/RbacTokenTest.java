package edu.bingol.backend.admin.rbac;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;

/** JWT profil talebi, eski (talepsiz) token geriye uyumu, profil degisiminde eski token reddi ve profil cozumu. */
class RbacTokenTest {

    private final JwtService jwt = new JwtService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final JwtAuthFilter filter = new JwtAuthFilter(jwt, redis);
    private final UserRepository users = mock(UserRepository.class);
    private final AdminProfileResolver resolver =
            new AdminProfileResolver(users, new AdminProperties(List.of("pinli@bingol.edu.tr")));

    @AfterEach
    void clear() {
        SecurityContextHolder.clearContext();
    }

    private User user(long id, String email, Role role, AdminProfile profile) {
        User u = new User();
        u.setId(id);
        u.setEmail(email);
        u.setRole(role);
        u.setAdminProfile(profile);
        return u;
    }

    private MockHttpServletRequest through(String token) throws Exception {
        SecurityContextHolder.clearContext();
        MockHttpServletRequest req = new MockHttpServletRequest();
        req.addHeader("Authorization", "Bearer " + token);
        filter.doFilter(req, new MockHttpServletResponse(), new MockFilterChain());
        return req;
    }

    @Test
    void adminTokenCarriesProfileClaimAndEmptyProfileMeansFull() {
        assertEquals("VIEWER", jwt.parse(jwt.createAccessToken(user(1, "a@bingol.edu.tr", Role.ADMIN, AdminProfile.VIEWER)))
                .adminProfile());
        assertEquals("FULL", jwt.parse(jwt.createAccessToken(user(1, "a@bingol.edu.tr", Role.ADMIN, null)))
                .adminProfile());
        assertNull(jwt.parse(jwt.createAccessToken(user(2, "u@bingol.edu.tr", Role.USER, null))).adminProfile());
        assertEquals("a@bingol.edu.tr",
                jwt.parse(jwt.createAccessToken(user(1, "a@bingol.edu.tr", Role.ADMIN, null))).email());
    }

    @Test
    void filterPutsProfileClaimOnRequest() throws Exception {
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.multiGet(anyList())).thenReturn(Arrays.asList(null, null, null, null));

        MockHttpServletRequest req =
                through(jwt.createAccessToken(user(1, "a@bingol.edu.tr", Role.ADMIN, AdminProfile.SUPPORT)));

        assertNotNull(SecurityContextHolder.getContext().getAuthentication());
        assertEquals("SUPPORT", req.getAttribute(JwtAuthFilter.ADMIN_PROFILE_ATTR));
        assertEquals("a@bingol.edu.tr", req.getAttribute(JwtAuthFilter.TOKEN_EMAIL_ATTR));
    }

    @Test
    void tokenIssuedBeforeProfileChangeIsRejected() throws Exception {
        when(redis.opsForValue()).thenReturn(ops);
        String old = jwt.createAccessToken(user(1, "a@bingol.edu.tr", Role.ADMIN, AdminProfile.FULL));
        long changedAt = System.currentTimeMillis() + 50; // profil degisimi (rolechg isareti) token'dan sonra
        when(ops.multiGet(anyList())).thenReturn(Arrays.asList(null, String.valueOf(changedAt), null, null));

        through(old);
        assertNull(SecurityContextHolder.getContext().getAuthentication());

        // degisimden sonra alinan yeni token kabul edilir
        when(ops.multiGet(anyList()))
                .thenReturn(Arrays.asList(null, String.valueOf(System.currentTimeMillis() - 5000), null, null));
        through(jwt.createAccessToken(user(1, "a@bingol.edu.tr", Role.ADMIN, AdminProfile.VIEWER)));
        assertNotNull(SecurityContextHolder.getContext().getAuthentication());
    }

    // --- profil cozumu ---

    private static Authentication auth(Object principal) {
        return new UsernamePasswordAuthenticationToken(principal, null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    }

    private static MockHttpServletRequest req(String claim, String email) {
        MockHttpServletRequest r = new MockHttpServletRequest();
        r.setAttribute(JwtAuthFilter.ADMIN_PROFILE_ATTR, claim);
        r.setAttribute(JwtAuthFilter.TOKEN_EMAIL_ATTR, email);
        return r;
    }

    @Test
    void basicAuthAdminIsFull() {
        assertEquals(AdminProfile.FULL, resolver.resolve(auth("admin"), new MockHttpServletRequest()).profile());
        assertEquals(AdminProfile.FULL, resolver.resolve(null, new MockHttpServletRequest()).profile());
    }

    @Test
    void claimIsUsedAndPinnedEmailAlwaysFull() {
        assertEquals(AdminProfile.VIEWER, resolver.resolve(auth(1L), req("VIEWER", "a@bingol.edu.tr")).profile());
        var pinned = resolver.resolve(auth(1L), req("VIEWER", "Pinli@bingol.edu.tr"));
        assertEquals(AdminProfile.FULL, pinned.profile());
        assertTrue(pinned.pinned());
    }

    @Test
    void oldTokenWithoutClaimResolvesFromUserRecord() {
        when(users.findById(7L)).thenReturn(Optional.of(user(7, "a@bingol.edu.tr", Role.ADMIN, AdminProfile.VIEWER)));
        assertEquals(AdminProfile.VIEWER, resolver.resolve(auth(7L), new MockHttpServletRequest()).profile());

        // kayitta profil bos (migrasyon oncesi) => FULL
        when(users.findById(8L)).thenReturn(Optional.of(user(8, "b@bingol.edu.tr", Role.ADMIN, null)));
        assertEquals(AdminProfile.FULL, resolver.resolve(auth(8L), new MockHttpServletRequest()).profile());

        // kaydi olmayan kimlik => FULL (geriye uyum)
        when(users.findById(9L)).thenReturn(Optional.empty());
        assertEquals(AdminProfile.FULL, resolver.resolve(auth(9L), new MockHttpServletRequest()).profile());

        // sabitli hesap, kayitta VIEWER olsa da FULL
        when(users.findById(10L)).thenReturn(Optional.of(user(10, "pinli@bingol.edu.tr", Role.ADMIN, AdminProfile.VIEWER)));
        assertEquals(AdminProfile.FULL, resolver.resolve(auth(10L), new MockHttpServletRequest()).profile());
        assertFalse(resolver.resolve(auth(7L), new MockHttpServletRequest()).pinned());
    }
}
