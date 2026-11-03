package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.accessban.ClientContexts;
import edu.bingol.backend.auth.AccountLock.AccountLockedException;
import edu.bingol.backend.auth.dto.LoginRequest;
import edu.bingol.backend.auth.dto.ResetPasswordRequest;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.token.RefreshTokenService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.RateLimitProperties;
import edu.bingol.backend.i18n.I18n;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpServletRequest;

/** PIN6: hesap basina 5 yanlis sifre -> 15 dk kilit (429 ACCOUNT_TEMP_LOCKED); controller baglantisi dahil. */
class AccountLockTest {

    private static final String EMAIL = "ali@bingol.edu.tr";

    private final FakeRedis redis = new FakeRedis();
    private final AccountLock lock = new AccountLock(redis.template);

    private final AuthService auth = mock(AuthService.class);
    private final LoginThrottle throttle = mock(LoginThrottle.class);
    private final AuthController controller = new AuthController(auth, mock(RateLimiter.class), mock(I18n.class),
            new ClientIp("10.0.0.0/8"), mock(ClientContexts.class), mock(JwtService.class), throttle,
            RateLimitProperties.defaults(), mock(RefreshTokenService.class));

    AccountLockTest() {
        controller.setAccountLock(lock);
    }

    private static MockHttpServletRequest from(String ip) {
        MockHttpServletRequest req = new MockHttpServletRequest();
        req.setRemoteAddr(ip);
        return req;
    }

    private void fail(String email, int n) {
        for (int i = 0; i < n; i++) {
            lock.recordFailure(email);
        }
    }

    private static ApiException invalidCredentials() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "x");
    }

    @Test
    void fourFailuresDoNotLockButTheFifthDoes() {
        fail(EMAIL, 4);
        assertDoesNotThrow(() -> lock.requireUnlocked(EMAIL));

        lock.recordFailure(EMAIL);

        AccountLockedException e = assertThrows(AccountLockedException.class, () -> lock.requireUnlocked(EMAIL));
        assertEquals("ACCOUNT_TEMP_LOCKED", e.code());
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, e.status());
        assertTrue(e.retryAfterSeconds() >= 1);
    }

    @Test
    void windowStartsAtFirstFailureAndLockRestartsFifteenMinutesAtTheFifth() {
        fail(EMAIL, 5);

        String key = AccountLock.key(EMAIL);
        // 1. ve 5. hatada TTL yazilir (kilit 5. hatadan itibaren tam 15 dk)
        verify(redis.template, times(2)).expire(eq(key), eq(Duration.ofMinutes(15)));
        assertEquals("lf:" + LoginThrottle.digest(EMAIL), key);
    }

    @Test
    void successClearsTheCounter() {
        fail(EMAIL, 4);

        lock.recordSuccess(EMAIL);
        fail(EMAIL, 4);

        assertDoesNotThrow(() -> lock.requireUnlocked(EMAIL));
    }

    @Test
    void plusAliasSharesTheCounterAndOtherAccountsAreIndependent() {
        fail("ali+1@bingol.edu.tr", 5);

        assertThrows(AccountLockedException.class, () -> lock.requireUnlocked(EMAIL));
        assertDoesNotThrow(() -> lock.requireUnlocked("veli@bingol.edu.tr"));
    }

    @Test
    void lockedErrorIsA429RateLimitedSoItCarriesRetryAfter() {
        fail(EMAIL, 5);

        RateLimitedException e = assertThrows(RateLimitedException.class, () -> lock.requireUnlocked(EMAIL));
        assertEquals("ACCOUNT_TEMP_LOCKED", e.code());
        assertEquals(600, e.retryAfterSeconds()); // FakeRedis getExpire = 600
    }

    // ---- controller baglantisi ----

    @Test
    void fiveWrongPasswordsLockTheAccountAndTheCorrectPasswordIsRejectedWhileLocked() {
        when(auth.login(anyString(), eq("999000"), any(), any())).thenThrow(invalidCredentials());
        when(auth.login(anyString(), eq("481952"), any(), any()))
                .thenReturn(new TokenResponse("a", "r", 900, "Bearer"));

        for (int i = 0; i < 5; i++) {
            ApiException e = assertThrows(ApiException.class,
                    () -> controller.login(new LoginRequest(EMAIL, "999000", null), from("203.0.113.9")));
            assertEquals("INVALID_CREDENTIALS", e.code()); // 5. deneme de 401
        }

        // 6. deneme yanlis sifre: kilit; DOGRU sifre de kilitliyken reddedilir
        ApiException wrong = assertThrows(ApiException.class,
                () -> controller.login(new LoginRequest(EMAIL, "999000", null), from("203.0.113.9")));
        ApiException right = assertThrows(ApiException.class,
                () -> controller.login(new LoginRequest(EMAIL, "481952", null), from("203.0.113.9")));
        assertEquals("ACCOUNT_TEMP_LOCKED", wrong.code());
        assertEquals("ACCOUNT_TEMP_LOCKED", right.code());
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, right.status());
        // kilitliyken parola kontrolune hic ulasilmadi: yalniz ilk 5 yanlis deneme auth'a gitti
        verify(auth, times(5)).login(anyString(), anyString(), any(), any());
        verify(auth, never()).login(anyString(), eq("481952"), any(), any());
    }

    @Test
    void successfulLoginResetsTheCounter() {
        when(auth.login(anyString(), eq("999000"), any(), any())).thenThrow(invalidCredentials());
        when(auth.login(anyString(), eq("481952"), any(), any()))
                .thenReturn(new TokenResponse("a", "r", 900, "Bearer"));

        for (int round = 0; round < 3; round++) {
            for (int i = 0; i < 4; i++) {
                assertThrows(ApiException.class,
                        () -> controller.login(new LoginRequest(EMAIL, "999000", null), from("203.0.113.9")));
            }
            // dogru giris sayaci sifirlar: bir sonraki turda yine 4 hata hakki var
            assertEquals("a",
                    controller.login(new LoginRequest(EMAIL, "481952", null), from("203.0.113.9")).accessToken());
        }
    }

    @Test
    void unknownAccountGetsTheSameCounterAndTheSameLockAnswer() {
        // var olmayan hesap da INVALID_CREDENTIALS doner (AuthService); sayac e-posta ozetine bagli: ayni kilit
        when(auth.login(anyString(), anyString(), any(), any())).thenThrow(invalidCredentials());

        for (int i = 0; i < 5; i++) {
            assertThrows(ApiException.class, () -> controller
                    .login(new LoginRequest("yok@bingol.edu.tr", "999000", null), from("203.0.113.9")));
        }

        ApiException e = assertThrows(ApiException.class, () -> controller
                .login(new LoginRequest("yok@bingol.edu.tr", "999000", null), from("203.0.113.9")));
        assertEquals("ACCOUNT_TEMP_LOCKED", e.code());
    }

    @Test
    void unverifiedEmailAnswerDoesNotCountTowardsTheLock() {
        when(auth.login(anyString(), anyString(), any(), any()))
                .thenThrow(new ApiException(HttpStatus.FORBIDDEN, "EMAIL_NOT_VERIFIED", "x"));

        for (int i = 0; i < 8; i++) {
            assertThrows(ApiException.class,
                    () -> controller.login(new LoginRequest(EMAIL, "481952", null), from("203.0.113.9")));
        }

        assertDoesNotThrow(() -> lock.requireUnlocked(EMAIL));
    }

    @Test
    void lockedAccountNeverReachesThePasswordCheck() {
        fail(EMAIL, 5);

        assertThrows(AccountLockedException.class,
                () -> controller.login(new LoginRequest(EMAIL, "481952", null), from("203.0.113.9")));

        verify(auth, never()).login(anyString(), anyString(), any(), any());
    }

    @Test
    void successfulPasswordResetClearsTheLock() {
        fail(EMAIL, 5);

        controller.resetPassword(new ResetPasswordRequest(EMAIL, "tok", "481952"), from("203.0.113.9"));

        assertDoesNotThrow(() -> lock.requireUnlocked(EMAIL));
    }
}
