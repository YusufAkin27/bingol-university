package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import edu.bingol.backend.accessban.AccessGuard;
import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.accessban.DeviceLogService;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/** Kimlik dogrulama uclarinda erisim engeli ve cihaz gunlugu (kayit/giris/yenileme). */
class AuthServiceAccessBanTest {

    private static final String EMAIL = "ali@bingol.edu.tr";

    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private final UserRepository users = mock(UserRepository.class);
    private final JwtService jwt = mock(JwtService.class);
    private final RefreshTokenService refresh = mock(RefreshTokenService.class);
    private final PendingRegistrationStore pending = mock(PendingRegistrationStore.class);
    private final VerificationService verification = mock(VerificationService.class);
    private final AccountCreator accounts = mock(AccountCreator.class);
    private final SessionService sessions = mock(SessionService.class);
    private final AccessGuard guard = mock(AccessGuard.class);
    private final DeviceLogService deviceLog = mock(DeviceLogService.class);
    private final AuthService auth = new AuthService(users, encoder, jwt, refresh, verification,
            new AdminProperties(List.of()), accounts, pending, sessions, new CatalogService());
    private final ClientContext ctx = new ClientContext("203.0.113.9", "a".repeat(64), "ANDROID", "1.0.0");
    private User user;

    @BeforeEach
    void setUp() {
        auth.setAccessControls(guard, deviceLog);
        user = new User();
        user.setId(7L);
        user.setEmail(EMAIL);
        user.setPasswordHash(encoder.encode("Sifre1234"));
        user.setEmailVerified(true);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(user));
        when(jwt.createAccessToken(any(), anyString())).thenReturn("access");
        when(jwt.accessTtl()).thenReturn(Duration.ofMinutes(15));
        when(refresh.issue(any(), anyString())).thenReturn("refresh");
    }

    @Test
    void loginSucceedsAndWritesDeviceLog() {
        auth.login(EMAIL, "Sifre1234", "mobile", ctx);

        verify(guard).require(ctx, 7L, "/api/auth/login");
        verify(deviceLog).record(7L, ctx, "LOGIN");
        verify(refresh).issue(7L, "mobile");
    }

    @Test
    void loginFromBlockedDeviceIsRejectedWithoutTokensOrSessionChanges() {
        doThrow(AccessGuard.accessBlocked()).when(guard).require(eq(ctx), eq(7L), anyString());

        ApiException e = assertThrows(ApiException.class, () -> auth.login(EMAIL, "Sifre1234", "mobile", ctx));

        assertEquals("ACCESS_BLOCKED", e.code());
        assertEquals(403, e.status().value());
        verify(refresh, never()).issue(any(), anyString());
        verify(sessions, never()).revokeClient(any(), anyString(), org.mockito.ArgumentMatchers.anyBoolean());
        verify(deviceLog, never()).record(any(), any(), anyString());
    }

    @Test
    void wrongPasswordNeverRevealsBlockState() {
        ApiException e = assertThrows(ApiException.class, () -> auth.login(EMAIL, "yanlis-sifre", "mobile", ctx));

        assertEquals("INVALID_CREDENTIALS", e.code());
        verifyNoInteractions(guard);
        verifyNoInteractions(deviceLog);
    }

    @Test
    void refreshFromBlockedDeviceIsRejectedAndSuccessfulRefreshIsLogged() {
        when(refresh.consumeSession("tok")).thenReturn(new RefreshTokenService.Session(7L, "mobile"));
        when(users.findById(7L)).thenReturn(Optional.of(user));

        auth.refresh("tok", ctx);
        verify(deviceLog).record(7L, ctx, "REFRESH");

        doThrow(AccessGuard.accessBlocked()).when(guard).require(eq(ctx), eq(7L), anyString());
        ApiException e = assertThrows(ApiException.class, () -> auth.refresh("tok", ctx));
        assertEquals("ACCESS_BLOCKED", e.code());
    }

    @Test
    void verifyEmailWritesRegisterDeviceLog() {
        PendingRegistrationStore.Pending p = new PendingRegistrationStore.Pending(encoder.encode("Sifre1234"), "Ali", "tr");
        when(pending.find(EMAIL)).thenReturn(p);
        when(users.findByEmail(EMAIL)).thenReturn(Optional.empty());
        // Baglam varsa deneme sayaci (e-posta, IP/64) cifti basinadir (3 argumanli dogrulama)
        when(verification.verify(EMAIL, "123456", "203.0.113.9")).thenReturn(true);
        when(accounts.create(EMAIL, p)).thenReturn(user);

        auth.verifyEmail(EMAIL, "123456", "mobile", ctx, "Sifre1234");

        verify(deviceLog).record(7L, ctx, "REGISTER");
    }

    @Test
    void legacyOverloadsWorkWithoutContext() {
        auth.login(EMAIL, "Sifre1234", "mobile");

        verify(guard, never()).require(any(), any(), anyString());
        verify(deviceLog, never()).record(any(), any(), anyString());
    }
}
