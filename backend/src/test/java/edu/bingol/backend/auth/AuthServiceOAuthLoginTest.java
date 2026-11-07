package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.PendingRegistrationStore;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.auth.token.SessionService;
import edu.bingol.backend.auth.token.VerificationService;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.LoginChallengeResponse;
import edu.bingol.backend.auth.twofactor.TwoFactorRequiredException;
import edu.bingol.backend.auth.twofactor.TwoFactorService;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * OAuth girisinin ortak son adimlari ({@code AuthService.finishLogin}): 2FA'li hesapta OAuth de 202 akisina girer,
 * yonetici terfisi yapilmaz, tek cihaz kurali isler; OAuth ile acilan (parolasiz) hesap parola ile giremez.
 */
class AuthServiceOAuthLoginTest {

    private final UserRepository users = mock(UserRepository.class);
    private final PendingRegistrationStore pending = mock(PendingRegistrationStore.class);
    private final SessionService sessions = mock(SessionService.class);
    private final JwtService jwt = mock(JwtService.class);
    private final RefreshTokenService refresh = mock(RefreshTokenService.class);
    private final TwoFactorService twoFactor = mock(TwoFactorService.class);
    private final AuthService auth = new AuthService(users, new BCryptPasswordEncoder(4), jwt, refresh,
            mock(VerificationService.class), new AdminProperties(List.of("yonetici@gmail.com")), mock(AccountCreator.class),
            pending, sessions, new CatalogService());

    AuthServiceOAuthLoginTest() {
        when(jwt.createAccessToken(any(), anyString())).thenReturn("access");
        when(jwt.accessTtl()).thenReturn(Duration.ofMinutes(15));
        when(refresh.issue(anyLong(), anyString())).thenReturn("refresh");
        auth.setTwoFactor(twoFactor);
    }

    private static User user(String email) {
        User u = new User();
        u.setId(9L);
        u.setEmail(email);
        u.setPasswordHash(User.NO_PASSWORD_PREFIX + "abc");
        u.setDisplayName("Kisi");
        u.setEmailVerified(true);
        u.setProfileCompletedAt(null);
        return u;
    }

    @Test
    void oauthLoginIssuesTokensAndAppliesTheSingleDeviceRuleForMobile() {
        // cok oturum varsayilan (V1460); tek cihaz kurali yalniz AUTH_SINGLE_MOBILE_SESSION=true iken uygulanir
        auth.setSingleMobileSession(true);
        TokenResponse t = auth.finishLogin(user("a@gmail.com"), "mobile", null, "/api/auth/oauth", false);

        assertEquals("access", t.accessToken());
        assertEquals("refresh", t.refreshToken());
        assertEquals(null, t.emailVerified()); // dogrulanmis hesap: ertelenmis isareti yok
        verify(sessions).revokeClient(9L, "mobile", true);
    }

    @Test
    void multiSessionByDefaultDoesNotRevokeOtherMobileSessions() {
        auth.finishLogin(user("a@gmail.com"), "mobile", null, "/api/auth/oauth", false);
        verify(sessions, never()).revokeClient(anyLong(), anyString(), anyBoolean());
    }

    @Test
    void webClientDoesNotRevokeOtherSessions() {
        auth.finishLogin(user("a@gmail.com"), "web", null, "/api/auth/oauth", false);
        verify(sessions, never()).revokeClient(anyLong(), anyString(), anyBoolean());
    }

    @Test
    void oauthLoginNeverPromotesAnAdminEmailAccount() {
        User u = user("yonetici@gmail.com");

        auth.finishLogin(u, "mobile", null, "/api/auth/oauth", false);

        assertEquals(Role.USER, u.getRole());
        verify(users, never()).save(any());
    }

    @Test
    void twoFactorAccountGetsTheChallengeInsteadOfTokensOnOauthLogin() {
        User u = user("iki@gmail.com");
        u.setTwoFactorEnabled(true);
        LoginChallengeResponse challenge = mock(LoginChallengeResponse.class);
        when(twoFactor.touchIfTrusted(eq(9L), any())).thenReturn(false);
        when(twoFactor.begin(eq(u), any(), eq("mobile"))).thenReturn(challenge);

        TwoFactorRequiredException e = assertThrows(TwoFactorRequiredException.class,
                () -> auth.finishLogin(u, "mobile", null, "/api/auth/oauth", false));

        assertEquals(challenge, e.challenge());
        verify(refresh, never()).issue(anyLong(), anyString()); // token YOK
        verify(sessions, never()).revokeClient(anyLong(), anyString(), anyBoolean());
    }

    @Test
    void suspendedAndDeletedAccountsCannotLogInWithOauth() {
        User suspended = user("s@gmail.com");
        suspended.setStatus(UserStatus.SUSPENDED);
        assertEquals("ACCOUNT_SUSPENDED", assertThrows(ApiException.class,
                () -> auth.finishLogin(suspended, "mobile", null, "/api/auth/oauth", false)).code());

        User deleted = user("d@gmail.com");
        deleted.setStatus(UserStatus.DELETED);
        assertEquals("INVALID_CREDENTIALS", assertThrows(ApiException.class,
                () -> auth.finishLogin(deleted, "mobile", null, "/api/auth/oauth", false)).code());
    }

    @Test
    void passwordlessOauthAccountCannotLogInWithAnyPassword() {
        User u = user("oauth@gmail.com");
        when(users.findByEmail("oauth@gmail.com")).thenReturn(Optional.of(u));

        for (String guess : new String[] {"Kx7-mQ2vLp9z", "!oauth:abc", "", "password"}) {
            if (guess.isEmpty()) {
                continue;
            }
            ApiException e = assertThrows(ApiException.class, () -> auth.login("oauth@gmail.com", guess, "mobile"), guess);
            assertEquals("INVALID_CREDENTIALS", e.code()); // varlik sizdirilmaz: bilinmeyen hesapla ayni cevap
        }
        verify(refresh, never()).issue(anyLong(), anyString());
    }

    @Test
    void passwordlessFlagsAreConsistent() {
        User u = user("x@gmail.com");
        assertFalse(u.hasPassword());
        assertFalse(u.isProfileCompleted());
        u.setPasswordHash("$2a$04$abcdefghijklmnopqrstuuabcdefghijklmnopqrstuvwxyz01234");
        org.junit.jupiter.api.Assertions.assertTrue(u.hasPassword());
        assertFalse(User.hasUsablePassword("!deleted:xyz"));
        assertFalse(User.hasUsablePassword(null));
        assertFalse(User.hasUsablePassword(""));
    }

    /** QA-AUTH-01: /auth/me parolasiz (yalniz OAuth) hesabi bildirir; istemci silme/baglama/2FA kapatmada bunu kullanir. */
    @Test
    void meReportsWhetherTheAccountHasAUsablePassword() {
        User oauthOnly = user("o@gmail.com");
        when(users.findById(9L)).thenReturn(Optional.of(oauthOnly));
        assertFalse(auth.me(9L).hasPassword());

        User withPassword = user("p@gmail.com");
        withPassword.setPasswordHash("$2a$04$abcdefghijklmnopqrstuuabcdefghijklmnopqrstuvwxyz01234");
        when(users.findById(9L)).thenReturn(Optional.of(withPassword));
        org.junit.jupiter.api.Assertions.assertTrue(auth.me(9L).hasPassword());
    }
}
