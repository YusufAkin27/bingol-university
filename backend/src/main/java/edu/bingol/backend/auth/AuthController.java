package edu.bingol.backend.auth;

import edu.bingol.backend.auth.dto.EmailRequest;
import edu.bingol.backend.auth.dto.LoginRequest;
import edu.bingol.backend.auth.dto.MessageResponse;
import edu.bingol.backend.auth.dto.RefreshRequest;
import edu.bingol.backend.auth.dto.RegisterRequest;
import edu.bingol.backend.auth.dto.ResetPasswordRequest;
import edu.bingol.backend.auth.dto.ResetTokenResponse;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.dto.UserView;
import edu.bingol.backend.auth.dto.VerifyRequest;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import org.springframework.context.i18n.LocaleContextHolder;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Uyelik ve oturum uclari. Is kurallari AuthService'te; burada yalnizca rate limit ve HTTP eslemesi var. */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService auth;
    private final RateLimiter limiter;
    private final I18n i18n;

    private final ClientIp clientIp;

    public AuthController(AuthService auth, RateLimiter limiter, I18n i18n, ClientIp clientIp) {
        this.clientIp = clientIp;
        this.i18n = i18n;
        this.auth = auth;
        this.limiter = limiter;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse register(@Valid @RequestBody RegisterRequest r, HttpServletRequest http) {
        limiter.check("register:ip:" + clientIp.of(http), 10, Duration.ofHours(1));
        Lang lang = r.language() != null ? Lang.of(r.language()) : Lang.of(LocaleContextHolder.getLocale());
        auth.register(r.email(), r.password(), r.displayName(), lang);
        return new MessageResponse(i18n.current("msg.register.sent"));
    }

    @PostMapping("/resend-code")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse resendCode(@Valid @RequestBody EmailRequest r, HttpServletRequest http) {
        limiter.check("resend:ip:" + clientIp.of(http), 10, Duration.ofHours(1));
        auth.resendCode(r.email());
        return new MessageResponse(i18n.current("msg.resend.sent"));
    }

    @PostMapping("/forgot-password")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse forgotPassword(@Valid @RequestBody EmailRequest r, HttpServletRequest http) {
        limiter.check("forgot:ip:" + clientIp.of(http), 10, Duration.ofHours(1));
        limiter.check("forgot:email:" + AuthService.normalizeEmail(r.email()), 5, Duration.ofHours(1));
        auth.forgotPassword(r.email());
        return new MessageResponse(i18n.current("msg.forgot.sent"));
    }

    @PostMapping("/verify-reset-code")
    public ResetTokenResponse verifyResetCode(@Valid @RequestBody VerifyRequest r, HttpServletRequest http) {
        limiter.check("vreset:ip:" + clientIp.of(http), 20, Duration.ofMinutes(10));
        return new ResetTokenResponse(auth.verifyResetCode(r.email(), r.code()));
    }

    @PostMapping("/reset-password")
    public MessageResponse resetPassword(@Valid @RequestBody ResetPasswordRequest r, HttpServletRequest http) {
        limiter.check("reset:ip:" + clientIp.of(http), 20, Duration.ofMinutes(10));
        auth.resetPassword(r.email(), r.resetToken(), r.newPassword());
        return new MessageResponse(i18n.current("msg.reset.done"));
    }

    @PostMapping("/verify-email")
    public TokenResponse verifyEmail(@Valid @RequestBody VerifyRequest r, HttpServletRequest http) {
        limiter.check("verify:ip:" + clientIp.of(http), 20, Duration.ofMinutes(10));
        limiter.check("verify:email:" + AuthService.normalizeEmail(r.email()), 10, Duration.ofMinutes(10));
        return auth.verifyEmail(r.email(), r.code());
    }

    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest r, HttpServletRequest http) {
        String email = AuthService.normalizeEmail(r.email());
        limiter.check("login:ip:" + clientIp.of(http), 30, Duration.ofMinutes(15));
        limiter.check("login:email:" + email, 10, Duration.ofMinutes(15));
        return auth.login(email, r.password());
    }

    @PostMapping("/refresh")
    public TokenResponse refresh(@Valid @RequestBody RefreshRequest r, HttpServletRequest http) {
        limiter.check("refresh:ip:" + clientIp.of(http), 60, Duration.ofMinutes(15));
        return auth.refresh(r.refreshToken());
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@Valid @RequestBody RefreshRequest r) {
        auth.logout(r.refreshToken());
    }

    @PostMapping("/logout-all")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logoutAll(Authentication authentication) {
        Long userId = (Long) authentication.getPrincipal();
        limiter.check("logoutall:user:" + userId, 5, Duration.ofMinutes(15));
        auth.logoutAll(userId);
    }

    @GetMapping("/me")
    public UserView me(Authentication authentication) {
        return auth.me((Long) authentication.getPrincipal());
    }
}
