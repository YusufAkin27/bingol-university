package edu.bingol.backend.auth;

import edu.bingol.backend.accessban.ClientContexts;
import edu.bingol.backend.auth.dto.ChangePasswordRequest;
import edu.bingol.backend.auth.dto.EmailRequest;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.dto.LoginRequest;
import edu.bingol.backend.auth.dto.MessageResponse;
import edu.bingol.backend.auth.dto.RefreshRequest;
import edu.bingol.backend.auth.dto.RegisterRequest;
import edu.bingol.backend.auth.dto.ResetPasswordRequest;
import edu.bingol.backend.auth.dto.ResetTokenResponse;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.dto.UserView;
import edu.bingol.backend.auth.dto.VerifyEmailRequest;
import edu.bingol.backend.auth.dto.VerifyRequest;
import edu.bingol.backend.common.ApiException;
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

/**
 * Uyelik ve oturum uclari. Is kurallari AuthService'te; burada yalnizca rate limit ve HTTP eslemesi var.
 * Hiz siniri anahtarlari: IP IPv6'da /64'e indirgenir ({@link ClientIp#limitKey}); e-posta anahtarlari +etiketten
 * arindirilmis kanonik adresin ozetidir (sabit uzunluk: Redis'i sisiremez, +alias ayni sayaci paylasir). Kampus NAT'i
 * icin IP sinirlari genis, e-posta/kimlik sinirlari (e-posta, IP) cifti basinadir: baskasinin hesabini kilitleyemez.
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService auth;
    private final RateLimiter limiter;
    private final I18n i18n;

    private final ClientIp clientIp;
    private final ClientContexts contexts;
    private final JwtService jwt;
    private final LoginThrottle loginThrottle;

    public AuthController(AuthService auth, RateLimiter limiter, I18n i18n, ClientIp clientIp,
                          ClientContexts contexts, JwtService jwt, LoginThrottle loginThrottle) {
        this.loginThrottle = loginThrottle;
        this.jwt = jwt;
        this.contexts = contexts;
        this.clientIp = clientIp;
        this.i18n = i18n;
        this.auth = auth;
        this.limiter = limiter;
    }

    /** Kod e-postasi gonderen uclar (register, resend, forgot) icin adres basina ortak gunluk tavan. */
    private void codeMailCap(String emailDigest) {
        limiter.check("codemail:day:" + emailDigest, 20, Duration.ofHours(24));
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse register(@Valid @RequestBody RegisterRequest r, HttpServletRequest http) {
        limiter.check("register:ip:" + clientIp.limitKey(http), 30, Duration.ofHours(1));
        // E-posta basina sinir: kod yenileme/posta bombalama ve bekleyen kaydi tekrar tekrar ezme engellenir.
        String ed = LoginThrottle.digest(AuthService.normalizeEmail(r.email()));
        limiter.check("register:email:" + ed, 5, Duration.ofHours(1));
        codeMailCap(ed);
        Lang lang = r.language() != null ? Lang.of(r.language()) : Lang.of(LocaleContextHolder.getLocale());
        auth.register(r.email(), r.password(), r.displayName(), lang, r.faculty(), r.department(), r.grade());
        return new MessageResponse(i18n.current("msg.register.sent"));
    }

    @PostMapping("/resend-code")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse resendCode(@Valid @RequestBody EmailRequest r, HttpServletRequest http) {
        limiter.check("resend:ip:" + clientIp.limitKey(http), 30, Duration.ofHours(1));
        String ed = LoginThrottle.digest(AuthService.normalizeEmail(r.email()));
        limiter.check("resend:email:" + ed, 5, Duration.ofHours(1));
        codeMailCap(ed);
        auth.resendCode(r.email());
        return new MessageResponse(i18n.current("msg.resend.sent"));
    }

    @PostMapping("/forgot-password")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse forgotPassword(@Valid @RequestBody EmailRequest r, HttpServletRequest http) {
        limiter.check("forgot:ip:" + clientIp.limitKey(http), 30, Duration.ofHours(1));
        String ed = LoginThrottle.digest(AuthService.normalizeEmail(r.email()));
        limiter.check("forgot:email:" + ed, 5, Duration.ofHours(1));
        codeMailCap(ed);
        auth.forgotPassword(r.email());
        return new MessageResponse(i18n.current("msg.forgot.sent"));
    }

    @PostMapping("/verify-reset-code")
    public ResetTokenResponse verifyResetCode(@Valid @RequestBody VerifyRequest r, HttpServletRequest http) {
        String ip = clientIp.limitKey(http);
        limiter.check("vreset:ip:" + ip, 60, Duration.ofMinutes(10));
        // (e-posta, ag) cifti: baskasinin adresine yanlis kod gondererek gercek kullanicinin butcesini tuketemezsiniz.
        limiter.check("vreset:email:" + LoginThrottle.digest(AuthService.normalizeEmail(r.email())) + ":" + ip,
                10, Duration.ofMinutes(10));
        return new ResetTokenResponse(auth.verifyResetCode(r.email(), r.code(), ip));
    }

    @PostMapping("/reset-password")
    public MessageResponse resetPassword(@Valid @RequestBody ResetPasswordRequest r, HttpServletRequest http) {
        limiter.check("reset:ip:" + clientIp.limitKey(http), 40, Duration.ofMinutes(10));
        auth.resetPassword(r.email(), r.resetToken(), r.newPassword());
        return new MessageResponse(i18n.current("msg.reset.done"));
    }

    @PostMapping("/verify-email")
    public TokenResponse verifyEmail(@Valid @RequestBody VerifyEmailRequest r, HttpServletRequest http) {
        String ip = clientIp.limitKey(http);
        limiter.check("verify:ip:" + ip, 60, Duration.ofMinutes(10));
        String ed = LoginThrottle.digest(AuthService.normalizeEmail(r.email()));
        limiter.check("verify:email:" + ed + ":" + ip, 10, Duration.ofMinutes(10));
        limiter.check("verify:email:" + ed, 60, Duration.ofMinutes(10));
        return auth.verifyEmail(r.email(), r.code(), r.client(), contexts.of(http), r.password());
    }

    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest r, HttpServletRequest http) {
        String email = AuthService.normalizeEmail(r.email());
        String ip = clientIp.limitKey(http);
        limiter.check("login:ip:" + ip, 200, Duration.ofMinutes(15));
        // Yalniz BASARISIZ denemeler (e-posta, ag) cifti basina sayilir; kilit baskasinin hesabini kapatamaz.
        loginThrottle.check(email, ip);
        TokenResponse res;
        try {
            res = auth.login(email, r.password(), r.client(), contexts.of(http));
        } catch (ApiException e) {
            if ("INVALID_CREDENTIALS".equals(e.code())) {
                loginThrottle.recordFailure(email, ip);
            }
            throw e;
        }
        loginThrottle.recordSuccess(email, ip);
        return res;
    }

    @PostMapping("/refresh")
    public TokenResponse refresh(@Valid @RequestBody RefreshRequest r, HttpServletRequest http) {
        limiter.check("refresh:ip:" + clientIp.limitKey(http), 300, Duration.ofMinutes(15));
        return auth.refresh(r.refreshToken(), contexts.of(http));
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

    /** 200 + yeni token cifti: diger tum oturumlar kapanir, istemci yeni cifti saklamalidir. */
    @PostMapping("/change-password")
    public TokenResponse changePassword(@Valid @RequestBody ChangePasswordRequest r, Authentication authentication,
                                        HttpServletRequest http) {
        Long userId = (Long) authentication.getPrincipal();
        limiter.check("chpw:user:" + userId, 5, Duration.ofHours(1));
        limiter.check("chpw:ip:" + clientIp.limitKey(http), 30, Duration.ofHours(1));
        return auth.changePassword(userId, r.currentPassword(), r.newPassword(), callerClient(http));
    }

    /** Istegi yapan access token'in istemci turu (`cl`); yoksa web. */
    private String callerClient(HttpServletRequest http) {
        String h = http.getHeader("Authorization");
        JwtService.Identity id = h != null && h.startsWith("Bearer ") ? jwt.parse(h.substring(7).trim()) : null;
        return id == null ? null : id.client();
    }

    @GetMapping("/me")
    public UserView me(Authentication authentication) {
        return auth.me((Long) authentication.getPrincipal());
    }
}
