package edu.bingol.backend.auth.twofactor;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.accessban.ClientContexts;
import edu.bingol.backend.auth.AuthService;
import edu.bingol.backend.auth.dto.MessageResponse;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.ChallengeRequest;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.CodeRequest;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.DeviceView;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.DisableRequest;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.EnabledResponse;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.ResendResponse;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.StatusResponse;
import edu.bingol.backend.auth.twofactor.TwoFactorDtos.TwoFactorLoginRequest;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.RateLimitProperties;
import edu.bingol.backend.i18n.I18n;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Iki faktorlu dogrulama uclari (docs/TWO_FACTOR_API.md). Giris ikinci adimi herkese aciktir (challenge jetonu
 * kimlik yerine gecer); ayar uclari JWT ister (SecurityConfig: /api/auth/2fa/**). Is kurallari AuthService /
 * TwoFactorService'te; burada yalnizca hiz siniri + HTTP eslemesi var.
 */
@RestController
@RequestMapping("/api/auth")
public class TwoFactorController {

    private final AuthService auth;
    private final TwoFactorService twoFactor;
    private final RateLimiter limiter;
    private final ClientIp clientIp;
    private final ClientContexts contexts;
    private final RateLimitProperties limits;
    private final I18n i18n;
    private final JwtService jwt;

    public TwoFactorController(AuthService auth, TwoFactorService twoFactor, RateLimiter limiter, ClientIp clientIp,
                               ClientContexts contexts, RateLimitProperties limits, I18n i18n, JwtService jwt) {
        this.auth = auth;
        this.twoFactor = twoFactor;
        this.limiter = limiter;
        this.clientIp = clientIp;
        this.contexts = contexts;
        this.limits = limits;
        this.i18n = i18n;
        this.jwt = jwt;
    }

    // ------------------------------------------------------------------ giris ikinci adimi (herkese acik)

    @PostMapping("/login/2fa")
    public TokenResponse loginTwoFactor(@Valid @RequestBody TwoFactorLoginRequest r, HttpServletRequest http) {
        String ip = clientIp.limitKey(http);
        limiter.check("tf2:ip:" + ip, limits.verifyIpMax(), Duration.ofMinutes(10));
        // Challenge basina: kod tahmini bu jetonla 10 dk'da en fazla 10 istek (ayrica kod/challenge kendi sinirlari var)
        limiter.check("tf2:ch:" + digest(r.challengeToken()), 10, Duration.ofMinutes(10));
        return auth.completeTwoFactorLogin(r.challengeToken(), r.code(), r.trust(), contexts.of(http));
    }

    @PostMapping("/login/2fa/resend")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public ResendResponse resendLoginCode(@Valid @RequestBody ChallengeRequest r, HttpServletRequest http) {
        limiter.check("tf2r:ip:" + clientIp.limitKey(http), limits.codeIpMax(), Duration.ofHours(1));
        // En cok 3 yeniden gonderme / 10 dk (challenge basina)
        limiter.check("tf2:resend:" + digest(r.challengeToken()), 3, Duration.ofMinutes(10));
        return new ResendResponse(auth.resendTwoFactorCode(r.challengeToken(), contexts.of(http)));
    }

    // ------------------------------------------------------------------ ayarlar (JWT)

    @GetMapping("/2fa")
    public StatusResponse status(Authentication authentication, HttpServletRequest http) {
        Long userId = userId(authentication);
        limiter.check("tf:status:user:" + userId, 120, Duration.ofMinutes(10));
        return twoFactor.status(userId, deviceOf(http));
    }

    @PostMapping("/2fa/enable/request")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public MessageResponse requestEnable(Authentication authentication, HttpServletRequest http) {
        Long userId = userId(authentication);
        limiter.check("tf:enreq:user:" + userId, 5, Duration.ofHours(1));
        limiter.check("tf:enreq:ip:" + clientIp.limitKey(http), limits.codeIpMax(), Duration.ofHours(1));
        twoFactor.requestEnable(userId);
        return new MessageResponse(i18n.current("msg.twofactor.code.sent"));
    }

    @PostMapping("/2fa/enable/confirm")
    public EnabledResponse confirmEnable(@Valid @RequestBody CodeRequest r, Authentication authentication,
                                         HttpServletRequest http) {
        Long userId = userId(authentication);
        limiter.check("tf:enconf:user:" + userId, 10, Duration.ofMinutes(10));
        limiter.check("tf:enconf:ip:" + clientIp.limitKey(http), limits.verifyIpMax(), Duration.ofMinutes(10));
        twoFactor.confirmEnable(userId, r.code(), contexts.of(http), r.closeOthers());
        return new EnabledResponse(true, r.closeOthers() ? auth.reissueTokens(userId, callerClient(http), contexts.of(http)) : null);
    }

    /**
     * Sifre ister (yanlis sifre 400 INVALID_PASSWORD); tum guvenilen cihazlar silinir, kullaniciya bildirim + e-posta
     * gider. closeOtherSessions=true ise oturumlar kapanir ve yanitta bu cihaz icin yeni cift ({@code session}) gelir.
     */
    @PostMapping("/2fa/disable")
    public EnabledResponse disable(@Valid @RequestBody DisableRequest r, Authentication authentication,
                                   HttpServletRequest http) {
        Long userId = userId(authentication);
        // Calinmis oturumla sifre tahmini: kullanici basina dar, IP basina genis
        limiter.check("tf:disable:user:" + userId, 5, Duration.ofMinutes(15));
        limiter.check("tf:disable:ip:" + clientIp.limitKey(http), limits.changePasswordIpMax(), Duration.ofHours(1));
        twoFactor.disable(userId, r.password(), r.closeOthers());
        return new EnabledResponse(false, r.closeOthers() ? auth.reissueTokens(userId, callerClient(http), contexts.of(http)) : null);
    }

    @GetMapping("/2fa/devices")
    public List<DeviceView> devices(Authentication authentication, HttpServletRequest http) {
        Long userId = userId(authentication);
        limiter.check("tf:devices:user:" + userId, 120, Duration.ofMinutes(10));
        return twoFactor.listDevices(userId, deviceOf(http));
    }

    @DeleteMapping("/2fa/devices/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeDevice(@PathVariable Long id, Authentication authentication) {
        Long userId = userId(authentication);
        limiter.check("tf:devdel:user:" + userId, 30, Duration.ofHours(1));
        twoFactor.removeDevice(userId, id);
    }

    // ------------------------------------------------------------------ yardimcilar

    private static Long userId(Authentication authentication) {
        return (Long) authentication.getPrincipal();
    }

    /** Istegi yapan access token'in istemci turu (`cl`); yoksa web. */
    private String callerClient(HttpServletRequest http) {
        String h = http.getHeader("Authorization");
        JwtService.Identity id = h != null && h.startsWith("Bearer ") ? jwt.parse(h.substring(7).trim()) : null;
        return id == null ? null : id.client();
    }

    private String deviceOf(HttpServletRequest http) {
        ClientContext c = contexts.of(http);
        return c == null ? null : c.deviceHash();
    }

    /** Challenge jetonunun kisa ozeti (hiz siniri anahtari: ham jeton Redis anahtarina yazilmaz). */
    private static String digest(String token) {
        return Hashing.sha256(token).substring(0, 32);
    }
}
