package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.session.UserSessionService;
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
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/** Cok oturum: AuthService'in oturum kimligi (sid) ile entegrasyonu (login/refresh/logout/calinti). */
class AuthServiceSessionsTest {

    private static final String EMAIL = "ali@gmail.com";
    private static final String PW = "Kx7-mQ2vLp9z";

    private final UserRepository users = mock(UserRepository.class);
    private final SessionService sessions = mock(SessionService.class);
    private final JwtService jwt = mock(JwtService.class);
    private final RefreshTokenService refresh = mock(RefreshTokenService.class);
    private final UserSessionService userSessions = mock(UserSessionService.class);
    private final ClientContext ctx = new ClientContext("203.0.113.9", "a".repeat(64), "ANDROID", "2.2.0", "Pixel 8");
    private final User user = user();
    private final AuthService auth = new AuthService(users, new BCryptPasswordEncoder(4), jwt, refresh,
            mock(VerificationService.class), new AdminProperties(List.of()), mock(AccountCreator.class),
            mock(PendingRegistrationStore.class), sessions, new CatalogService());

    AuthServiceSessionsTest() {
        auth.setUserSessions(userSessions);
        when(jwt.accessTtl()).thenReturn(Duration.ofMinutes(15));
        when(users.findByEmail(EMAIL)).thenReturn(Optional.of(user));
        when(users.findById(7L)).thenReturn(Optional.of(user));
    }

    private static User user() {
        User u = new User();
        u.setId(7L);
        u.setEmail(EMAIL);
        u.setEmailVerified(true);
        u.setLanguage("tr");
        u.setPasswordHash(new BCryptPasswordEncoder(4).encode(PW));
        return u;
    }

    @Test
    void loginOpensASessionAndIssuesSidBearingTokensWithoutClosingOthers() {
        when(userSessions.open(eq(7L), eq("mobile"), anyLong(), eq(ctx), eq(true))).thenReturn("sid1");
        when(refresh.issue(eq(7L), eq("mobile"), anyLong(), eq("sid1"))).thenReturn("rt1");
        when(jwt.createAccessToken(user, "mobile", "sid1")).thenReturn("at1");

        TokenResponse t = auth.login(EMAIL, PW, "mobile", ctx);

        assertEquals("at1", t.accessToken());
        assertEquals("rt1", t.refreshToken());
        verify(sessions, never()).revokeClient(any(), anyString(), org.mockito.ArgumentMatchers.anyBoolean());
        verify(sessions, never()).revokeAll(any());
    }

    @Test
    void loginFallsBackToSidlessTokensWhenTheSessionRecordCannotBeOpened() {
        when(userSessions.open(any(), anyString(), anyLong(), any(), org.mockito.ArgumentMatchers.anyBoolean())).thenReturn(null);
        when(refresh.issue(eq(7L), eq("mobile"), anyLong())).thenReturn("rt-legacy");
        when(jwt.createAccessToken(user, "mobile")).thenReturn("at-legacy");

        TokenResponse t = auth.login(EMAIL, PW, "mobile", ctx);

        assertEquals("rt-legacy", t.refreshToken());
        assertEquals("at-legacy", t.accessToken());
    }

    @Test
    void refreshRotationKeepsTheSessionId() {
        when(refresh.consumeSession("tok")).thenReturn(new RefreshTokenService.Session(7L, "mobile", 5_000L, "sidX"));
        when(userSessions.refreshed(7L, "sidX", "mobile", 5_000L, ctx)).thenReturn("sidX");
        when(refresh.issue(7L, "mobile", 5_000L, "sidX")).thenReturn("next");
        when(jwt.createAccessToken(user, "mobile", "sidX")).thenReturn("at");

        TokenResponse t = auth.refresh("tok", ctx);

        assertEquals("next", t.refreshToken());
        verify(refresh).issue(7L, "mobile", 5_000L, "sidX");
    }

    @Test
    void refreshOfAPreMultiSessionChainAdoptsItIntoARecord() {
        when(refresh.consumeSession("old")).thenReturn(new RefreshTokenService.Session(7L, "mobile", 5_000L));
        when(userSessions.refreshed(7L, null, "mobile", 5_000L, ctx)).thenReturn("adopted");
        when(refresh.issue(7L, "mobile", 5_000L, "adopted")).thenReturn("next");

        assertEquals("next", auth.refresh("old", ctx).refreshToken());
    }

    @Test
    void refreshWhereTheSessionWasClosedFromMyDevicesMidRotationClosesTheNewPair() {
        when(refresh.consumeSession("tok")).thenReturn(new RefreshTokenService.Session(7L, "mobile", 5_000L, "sidX"));
        when(userSessions.refreshed(7L, "sidX", "mobile", 5_000L, ctx)).thenReturn("sidX");
        when(refresh.issue(7L, "mobile", 5_000L, "sidX")).thenReturn("next");
        when(sessions.isSidRevoked("sidX")).thenReturn(false, true);

        assertThrows(ApiException.class, () -> auth.refresh("tok", ctx));

        verify(refresh).revoke("next");
    }

    @Test
    void refreshOfASessionAlreadyClosedIsRejectedBeforeAnyTokenIsIssued() {
        when(refresh.consumeSession("tok")).thenReturn(new RefreshTokenService.Session(7L, "mobile", 5_000L, "sidX"));
        when(sessions.isSidRevoked("sidX")).thenReturn(true);

        ApiException e = assertThrows(ApiException.class, () -> auth.refresh("tok", ctx));

        assertEquals("INVALID_REFRESH_TOKEN", e.code());
        verify(refresh, never()).issue(any(), anyString(), anyLong(), anyString());
    }

    @Test
    void logoutClosesOnlyThisSessionsRecordAndAccessToken() {
        when(refresh.revoke("rt")).thenReturn(new RefreshTokenService.Session(7L, "mobile", 5_000L, "sidX"));

        auth.logout("rt");

        verify(userSessions).markRevoked("sidX");
        verify(sessions).revokeSession(7L, "sidX");
        verify(sessions, never()).revokeAll(any());
    }

    @Test
    void logoutOfASidlessLegacyTokenTouchesNoSessionRecord() {
        when(refresh.revoke("rt")).thenReturn(new RefreshTokenService.Session(7L, "mobile", 5_000L));

        auth.logout("rt");

        verify(userSessions, never()).markRevoked(any());
        verify(sessions, never()).revokeSession(any(), any());
    }

    @Test
    void logoutWithFcmTokenStillRemovesThatDevice() {
        when(refresh.peekUserId("rt")).thenReturn(7L);

        auth.logout("rt", "fcm-1");

        verify(sessions).deviceLoggedOut(7L, "fcm-1");
    }

    @Test
    void stolenTokenReuseClosesOnlyThatSessionFamilyAndItsSid() {
        when(refresh.consumeSession("used")).thenReturn(null);
        when(refresh.findReuse("used")).thenReturn(Optional.of(new RefreshTokenService.Reuse(7L, "mobile", 5_000L, "sidX")));

        assertThrows(ApiException.class, () -> auth.refresh("used", ctx));

        verify(refresh).revokeFamily(7L, "mobile", 5_000L);
        verify(userSessions).markFamilyRevoked(7L, 5_000L);
        verify(sessions).revokeSession(7L, "sidX");
        verify(sessions, never()).revokeAll(any());
    }
}
