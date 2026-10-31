package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.dto.ChangePasswordRequest;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import jakarta.validation.Validation;
import java.time.Clock;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/** POST /api/auth/change-password: servis kurallari, oturum iptali (gercek SessionService + filtre) ve rate limit. */
class ChangePasswordTest {

    private static final BCryptPasswordEncoder ENC = new BCryptPasswordEncoder(4);

    private final Map<String, String> store = new HashMap<>();
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final JwtService jwt = new JwtService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final RefreshTokenService refresh = mock(RefreshTokenService.class);
    private final SessionService sessions = new SessionService(refresh, redis, jwt, Clock.systemUTC(),
            mock(ApplicationEventPublisher.class));
    private final JwtAuthFilter filter = new JwtAuthFilter(jwt, redis);
    private final UserRepository users = mock(UserRepository.class);
    private final MailService mail = mock(MailService.class);
    private final AuthService auth = new AuthService(users, ENC, jwt, refresh, mock(VerificationService.class),
            new AdminProperties(List.of()), mock(AccountCreator.class), mock(PendingRegistrationStore.class),
            sessions, new CatalogService());
    private final User user = new User();

    ChangePasswordTest() {
        org.springframework.test.util.ReflectionTestUtils.setField(auth, "mail", mail);
        user.setId(7L);
        user.setEmail("ali@bingol.edu.tr");
        user.setRole(Role.USER);
        user.setEmailVerified(true);
        user.setLanguage("en");
        user.setPasswordHash(ENC.encode("Eski12345"));
        when(users.findById(7L)).thenReturn(Optional.of(user));
        when(refresh.issue(7L, "mobile")).thenReturn("rt-new");
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

    private boolean accepted(String bearer) throws Exception {
        SecurityContextHolder.clearContext();
        MockHttpServletRequest req = new MockHttpServletRequest();
        req.addHeader("Authorization", "Bearer " + bearer);
        filter.doFilter(req, new MockHttpServletResponse(), new MockFilterChain());
        return SecurityContextHolder.getContext().getAuthentication() != null;
    }

    @Test
    void correctPasswordUpdatesHashRevokesOthersAndKeepsCallerLoggedIn() throws Exception {
        String oldToken = jwt.createAccessToken(user, "mobile");
        String oldWeb = jwt.createAccessToken(user, "web");
        assertTrue(accepted(oldToken));

        TokenResponse r = auth.changePassword(7L, "Eski12345", "Yeni-Sifre-912", "mobile");

        assertTrue(ENC.matches("Yeni-Sifre-912", user.getPasswordHash()));
        verify(users).save(user);
        verify(refresh).revokeAll(7L);
        assertFalse(accepted(oldToken), "eski mobil access token iptal olmali");
        assertFalse(accepted(oldWeb), "diger istemcinin access token'i da iptal olmali");
        assertTrue(accepted(r.accessToken()), "yeni access token hemen gecerli olmali");
        assertEquals("rt-new", r.refreshToken());
        assertEquals("mobile", jwt.parse(r.accessToken()).client());
        assertEquals("Bearer", r.tokenType());
        verify(mail).sendPasswordChanged(anyString(), anyString(), org.mockito.ArgumentMatchers.eq(Lang.EN));
    }

    @Test
    void newTokenSurvivesRevokeEvenWithinSameMillisecond() throws Exception {
        for (int i = 0; i < 200; i++) {
            store.clear();
            TokenResponse r = auth.changePassword(7L, "Eski12345", "Yeni-Sifre-912", "mobile");
            assertTrue(accepted(r.accessToken()));
            user.setPasswordHash(ENC.encode("Eski12345"));
        }
    }

    @Test
    void wrongCurrentPasswordIs403AndChangesNothing() {
        ApiException e = assertThrows(ApiException.class,
                () -> auth.changePassword(7L, "Yanlis123", "Yeni-Sifre-912", "mobile"));

        assertEquals("WRONG_PASSWORD", e.code());
        assertEquals(403, e.status().value());
        assertTrue(ENC.matches("Eski12345", user.getPasswordHash()));
        verify(users, never()).save(any());
        verify(refresh, never()).revokeAll(any());
        verify(mail, never()).sendPasswordChanged(any(), any(), any());
    }

    @Test
    void samePasswordIs422() {
        ApiException e = assertThrows(ApiException.class,
                () -> auth.changePassword(7L, "Eski12345", "Eski12345", "mobile"));

        assertEquals("PASSWORD_UNCHANGED", e.code());
        assertEquals(422, e.status().value());
        verify(users, never()).save(any());
        verify(refresh, never()).revokeAll(any());
    }

    @Test
    void mailFailureDoesNotBreakChange() {
        doThrow(new RuntimeException("smtp")).when(mail).sendPasswordChanged(any(), any(), any());

        TokenResponse r = auth.changePassword(7L, "Eski12345", "Yeni-Sifre-912", "mobile");

        assertEquals("rt-new", r.refreshToken());
    }

    @Test
    void weakNewPasswordFailsValidation() {
        var v = Validation.buildDefaultValidatorFactory().getValidator();

        // En az uzunluk/guc artik PasswordPolicy'de (serviste, PASSWORD_TOO_WEAK); DTO yalniz ust siniri (72) denetler
        assertTrue(v.validate(new ChangePasswordRequest("Eski12345", "kisa")).isEmpty());
        ApiException weak = assertThrows(ApiException.class, () -> auth.changePassword(7L, "Eski12345", "kisa", "mobile"));
        assertEquals("PASSWORD_TOO_WEAK", weak.code());
        assertEquals(400, weak.status().value());
        verify(users, never()).save(any());
        assertFalse(v.validate(new ChangePasswordRequest("Eski12345", "x".repeat(73))).isEmpty());
        assertFalse(v.validate(new ChangePasswordRequest("", "Yeni-Sifre-912")).isEmpty());
        assertTrue(v.validate(new ChangePasswordRequest("Eski12345", "Yeni-Sifre-912")).isEmpty());
    }

    @Test
    void controllerRateLimitsPerUserAndIpBeforeTouchingService() {
        RateLimiter limiter = mock(RateLimiter.class);
        AuthService svc = mock(AuthService.class);
        ClientIp ip = mock(ClientIp.class);
        MockHttpServletRequest http = new MockHttpServletRequest();
        when(ip.of(http)).thenReturn("1.2.3.4");
        when(ip.limitKey(http)).thenReturn("1.2.3.4");
        AuthController c = new AuthController(svc, limiter, null, ip, null, jwt, null,
                edu.bingol.backend.config.RateLimitProperties.defaults(), null);
        var authn = new TestingAuthenticationToken(7L, null);
        doThrow(new RateLimitedException(60)).when(limiter).check("chpw:user:7", 5, Duration.ofHours(1));

        assertThrows(RateLimitedException.class,
                () -> c.changePassword(new ChangePasswordRequest("Eski12345", "Yeni-Sifre-912"), authn, http));

        verify(svc, never()).changePassword(any(), any(), any(), any());
        // IP penceresi de uygulanir
        doThrow(new RateLimitedException(60)).when(limiter).check("chpw:ip:1.2.3.4", 600, Duration.ofHours(1));
        org.mockito.Mockito.doNothing().when(limiter).check("chpw:user:7", 5, Duration.ofHours(1));
        assertThrows(RateLimitedException.class,
                () -> c.changePassword(new ChangePasswordRequest("Eski12345", "Yeni-Sifre-912"), authn, http));
        verify(svc, never()).changePassword(any(), any(), any(), any());
    }
}
