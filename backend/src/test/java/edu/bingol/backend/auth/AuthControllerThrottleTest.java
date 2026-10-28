package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.accessban.ClientContexts;
import edu.bingol.backend.auth.dto.EmailRequest;
import edu.bingol.backend.auth.dto.LoginRequest;
import edu.bingol.backend.auth.dto.RegisterRequest;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.i18n.I18n;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpServletRequest;

/** Controller hiz siniri baglantilari: IPv6 /64 anahtari, e-posta basina sinir, yalniz basarisiz giris sayimi. */
class AuthControllerThrottleTest {

    private static final String EMAIL = "ali@bingol.edu.tr";
    private static final String IP64 = "v6:2001:0db8:0001:0002::/64";

    private final AuthService auth = mock(AuthService.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final LoginThrottle throttle = mock(LoginThrottle.class);
    private final AuthController controller = new AuthController(auth, limiter, mock(I18n.class),
            new ClientIp("10.0.0.0/8"), mock(ClientContexts.class), mock(JwtService.class), throttle);

    private static MockHttpServletRequest from(String ip) {
        MockHttpServletRequest req = new MockHttpServletRequest();
        req.setRemoteAddr(ip);
        return req;
    }

    @Test
    void ipv6AddressesOfTheSame64ShareTheLoginIpKey() {
        controller.login(new LoginRequest(EMAIL, "Sifre1234", null), from("2001:db8:1:2:aaaa::1"));
        controller.login(new LoginRequest(EMAIL, "Sifre1234", null), from("2001:db8:1:2:bbbb::2"));

        verify(limiter, org.mockito.Mockito.times(2)).check(eq("login:ip:" + IP64), anyInt(), any(Duration.class));
    }

    @Test
    void failedLoginIsRecordedPerEmailAndClient() {
        when(auth.login(anyString(), anyString(), any(), any()))
                .thenThrow(new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "x"));

        assertThrows(ApiException.class,
                () -> controller.login(new LoginRequest(EMAIL, "yanlis", null), from("203.0.113.9")));

        verify(throttle).recordFailure(EMAIL, "203.0.113.9");
        verify(throttle, never()).recordSuccess(anyString(), anyString());
    }

    @Test
    void unverifiedEmailAnswerIsNotCountedAsAFailure() {
        when(auth.login(anyString(), anyString(), any(), any()))
                .thenThrow(new ApiException(HttpStatus.FORBIDDEN, "EMAIL_NOT_VERIFIED", "x"));

        assertThrows(ApiException.class,
                () -> controller.login(new LoginRequest(EMAIL, "dogru", null), from("203.0.113.9")));

        verify(throttle, never()).recordFailure(anyString(), anyString());
    }

    @Test
    void successfulLoginResetsTheCounterAndThrottleRunsBeforeThePasswordCheck() {
        when(auth.login(anyString(), anyString(), any(), any()))
                .thenReturn(new TokenResponse("a", "r", 900, "Bearer"));

        controller.login(new LoginRequest(EMAIL, "dogru", null), from("203.0.113.9"));

        InOrder order = inOrder(throttle, auth);
        order.verify(throttle).check(EMAIL, "203.0.113.9");
        order.verify(auth).login(anyString(), anyString(), any(), any());
        order.verify(throttle).recordSuccess(EMAIL, "203.0.113.9");
    }

    @Test
    void lockedPairNeverReachesBcrypt() {
        doThrow(new RateLimitedException(600)).when(throttle).check(anyString(), anyString());

        assertThrows(RateLimitedException.class,
                () -> controller.login(new LoginRequest(EMAIL, "x", null), from("6.6.6.6")));

        verify(auth, never()).login(anyString(), anyString(), any(), any());
    }

    @Test
    void registerHasPerEmailHourlyAndDailyLimitsKeyedByAliasDigest() {
        RegisterRequest r = new RegisterRequest("Ali+1@bingol.edu.tr", "Sifre1234", "Ali", true, null, null, null, null);

        controller.register(r, from("203.0.113.9"));

        String digest = LoginThrottle.digest("ali+1@bingol.edu.tr");
        assertEquals(LoginThrottle.digest("ali@bingol.edu.tr"), digest); // +etiket ayni sayaci paylasir
        verify(limiter).check("register:email:" + digest, 5, Duration.ofHours(1));
        verify(limiter).check("codemail:day:" + digest, 20, Duration.ofHours(24));
        verify(limiter).check(startsWith("register:ip:"), anyInt(), any(Duration.class));
    }

    @Test
    void registerOverTheEmailLimitIsRejectedBeforeAnyMailIsSent() {
        doThrow(new RateLimitedException(3000)).when(limiter)
                .check(startsWith("register:email:"), anyInt(), any(Duration.class));

        assertThrows(RateLimitedException.class, () -> controller.register(
                new RegisterRequest(EMAIL, "Sifre1234", "Ali", true, null, null, null, null), from("203.0.113.9")));

        verify(auth, never()).register(anyString(), anyString(), anyString(), any(), any(), any(), any());
    }

    @Test
    void resendAndForgotUseSharedDailyCodeMailCap() {
        String digest = LoginThrottle.digest(EMAIL);

        controller.resendCode(new EmailRequest(EMAIL), from("203.0.113.9"));
        controller.forgotPassword(new EmailRequest(EMAIL), from("203.0.113.9"));

        verify(limiter, org.mockito.Mockito.times(2)).check("codemail:day:" + digest, 20, Duration.ofHours(24));
        verify(limiter).check("resend:email:" + digest, 5, Duration.ofHours(1));
        verify(limiter).check("forgot:email:" + digest, 5, Duration.ofHours(1));
    }
}
