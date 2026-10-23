package edu.bingol.backend.auth;

import edu.bingol.backend.auth.dto.EmailRequest;
import edu.bingol.backend.auth.dto.LoginRequest;
import edu.bingol.backend.auth.dto.MessageResponse;
import edu.bingol.backend.auth.dto.RefreshRequest;
import edu.bingol.backend.auth.dto.RegisterRequest;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.dto.UserView;
import edu.bingol.backend.auth.dto.VerifyRequest;
import edu.bingol.backend.common.RateLimiter;
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

    public AuthController(AuthService auth, RateLimiter limiter) {
        this.auth = auth;
        this.limiter = limiter;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse register(@Valid @RequestBody RegisterRequest r, HttpServletRequest http) {
        limiter.check("register:ip:" + http.getRemoteAddr(), 10, Duration.ofHours(1));
        auth.register(r.email(), r.password(), r.displayName());
        return new MessageResponse("Doğrulama kodu e-posta adresinize gönderildi.");
    }

    @PostMapping("/resend-code")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse resendCode(@Valid @RequestBody EmailRequest r, HttpServletRequest http) {
        limiter.check("resend:ip:" + http.getRemoteAddr(), 10, Duration.ofHours(1));
        auth.resendCode(r.email());
        return new MessageResponse("Hesap uygunsa yeni kod e-posta adresinize gönderildi.");
    }

    @PostMapping("/verify-email")
    public TokenResponse verifyEmail(@Valid @RequestBody VerifyRequest r, HttpServletRequest http) {
        limiter.check("verify:ip:" + http.getRemoteAddr(), 20, Duration.ofMinutes(10));
        return auth.verifyEmail(r.email(), r.code());
    }

    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest r, HttpServletRequest http) {
        String email = AuthService.normalizeEmail(r.email());
        limiter.check("login:ip:" + http.getRemoteAddr(), 30, Duration.ofMinutes(15));
        limiter.check("login:email:" + email, 10, Duration.ofMinutes(15));
        return auth.login(email, r.password());
    }

    @PostMapping("/refresh")
    public TokenResponse refresh(@Valid @RequestBody RefreshRequest r, HttpServletRequest http) {
        limiter.check("refresh:ip:" + http.getRemoteAddr(), 60, Duration.ofMinutes(15));
        return auth.refresh(r.refreshToken());
    }

    @PostMapping("/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@Valid @RequestBody RefreshRequest r) {
        auth.logout(r.refreshToken());
    }

    @GetMapping("/me")
    public UserView me(Authentication authentication) {
        return auth.me((Long) authentication.getPrincipal());
    }
}
