package edu.bingol.backend.auth;

import edu.bingol.backend.auth.AuthService.TokenResponse;
import edu.bingol.backend.auth.AuthService.UserView;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Duration;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    public record RegisterRequest(@NotBlank @Email @Size(max = 254) String email,
                                  @NotBlank @Size(min = 8, max = 72) String password,
                                  @NotBlank @Size(max = 80) String displayName) {}

    public record EmailRequest(@NotBlank @Email @Size(max = 254) String email) {}

    public record VerifyRequest(@NotBlank @Email @Size(max = 254) String email,
                                @NotBlank @Size(min = 6, max = 6) String code) {}

    public record LoginRequest(@NotBlank @Email @Size(max = 254) String email,
                               @NotBlank @Size(max = 72) String password) {}

    public record RefreshRequest(@NotBlank @Size(max = 200) String refreshToken) {}

    private final AuthService auth;
    private final RateLimiter limiter;

    public AuthController(AuthService auth, RateLimiter limiter) {
        this.auth = auth;
        this.limiter = limiter;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public Map<String, String> register(@Valid @RequestBody RegisterRequest r, HttpServletRequest http) {
        limiter.check("register:ip:" + http.getRemoteAddr(), 10, Duration.ofHours(1));
        auth.register(r.email(), r.password(), r.displayName());
        return Map.of("message", "Doğrulama kodu e-posta adresinize gönderildi.");
    }

    @PostMapping("/resend-code")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public Map<String, String> resend(@Valid @RequestBody EmailRequest r, HttpServletRequest http) {
        limiter.check("resend:ip:" + http.getRemoteAddr(), 10, Duration.ofHours(1));
        auth.resendCode(r.email());
        return Map.of("message", "Hesap uygunsa yeni kod e-posta adresinize gönderildi.");
    }

    @PostMapping("/verify-email")
    public TokenResponse verify(@Valid @RequestBody VerifyRequest r, HttpServletRequest http) {
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
