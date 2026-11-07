package edu.bingol.backend.auth.oauth;

import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.accessban.ClientContexts;
import edu.bingol.backend.auth.AuthService;
import edu.bingol.backend.auth.dto.TokenResponse;
import edu.bingol.backend.auth.oauth.OAuthDtos.AppleLoginRequest;
import edu.bingol.backend.auth.oauth.OAuthDtos.GoogleLoginRequest;
import edu.bingol.backend.auth.oauth.OAuthDtos.LinkRequest;
import edu.bingol.backend.auth.oauth.OAuthDtos.LinkResponse;
import edu.bingol.backend.auth.oauth.OAuthDtos.OAuthLoginResponse;
import edu.bingol.backend.auth.twofactor.TwoFactorRequiredException;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.RateLimitProperties;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Google/Apple ile giris ve hesap baglama uclari. Ozellik bayragi kapaliyken (app.auth.oauth.enabled=false) hepsi
 * 404 OAUTH_DISABLED. Is kurallari OAuthService'te; burada yalniz hiz siniri + HTTP eslemesi.
 */
@RestController
@RequestMapping("/api/auth/oauth")
public class OAuthController {

    private final OAuthService oauth;
    private final AuthService auth;
    private final RateLimiter limiter;
    private final ClientIp clientIp;
    private final ClientContexts contexts;
    private final RateLimitProperties limits;

    public OAuthController(OAuthService oauth, AuthService auth, RateLimiter limiter, ClientIp clientIp,
                           ClientContexts contexts, RateLimitProperties limits) {
        this.oauth = oauth;
        this.auth = auth;
        this.limiter = limiter;
        this.clientIp = clientIp;
        this.contexts = contexts;
        this.limits = limits;
    }

    /** 200 {jeton cifti, profileCompleted, isNewUser}; 2FA'li hesapta 202 + challenge (token YOK). */
    @PostMapping("/google")
    public ResponseEntity<Object> google(@Valid @RequestBody GoogleLoginRequest r, HttpServletRequest http) {
        oauth.requireEnabled();
        ClientContext ctx = rateLimitLogin(http);
        return finish(oauth.signInGoogle(r.idToken()), r.client(), ctx);
    }

    @PostMapping("/apple")
    public ResponseEntity<Object> apple(@Valid @RequestBody AppleLoginRequest r, HttpServletRequest http) {
        oauth.requireEnabled();
        ClientContext ctx = rateLimitLogin(http);
        return finish(oauth.signInApple(r.identityToken(), r.nonce(), r.firstName(), r.lastName()), r.client(), ctx);
    }

    private ClientContext rateLimitLogin(HttpServletRequest http) {
        // IP: yalniz toplu/NAT tavani (genis); cihaz basina daha dar. Gecersiz token denemeleri ayrica sayilir.
        limiter.check("oauth:ip:" + clientIp.limitKey(http), limits.loginIpMax(), Duration.ofMinutes(15));
        ClientContext ctx = contexts.of(http);
        if (ctx != null && ctx.deviceHash() != null) {
            limiter.check("oauth:dev:" + ctx.deviceHash(), 60, Duration.ofMinutes(15));
        }
        return ctx;
    }

    private ResponseEntity<Object> finish(OAuthService.SignIn s, String client, ClientContext ctx) {
        TokenResponse t;
        try {
            // Varsayilan istemci mobile (tek cihaz kurali); 2FA'li hesapta 202 akisi, yonetici terfisi YOK
            t = auth.finishLogin(s.user(), client == null ? "mobile" : client, ctx, "/api/auth/oauth", false);
        } catch (TwoFactorRequiredException e) {
            return ResponseEntity.status(HttpStatus.ACCEPTED).body(e.challenge());
        }
        return ResponseEntity.ok(OAuthLoginResponse.of(t, s.user(), s.isNew()));
    }

    /** KIMLIKLI: mevcut hesaba saglayici baglar (yeniden dogrulama zorunlu). */
    @PostMapping("/link")
    public LinkResponse link(@Valid @RequestBody LinkRequest r, Authentication authentication, HttpServletRequest http) {
        oauth.requireEnabled();
        Long uid = (Long) authentication.getPrincipal();
        limiter.check("oauthlink:user:" + uid, 10, Duration.ofHours(1));
        limiter.check("oauthlink:ip:" + clientIp.limitKey(http), limits.loginIpMax(), Duration.ofMinutes(15));
        OAuthProvider provider = parse(r.provider());
        oauth.link(uid, provider, r.token(), r.nonce(), r.password(),
                r.reauthProvider() == null ? null : parse(r.reauthProvider()), r.reauthToken(), r.reauthNonce());
        return new LinkResponse(true);
    }

    @DeleteMapping("/link/{provider}")
    public LinkResponse unlink(@PathVariable String provider, Authentication authentication) {
        oauth.requireEnabled();
        Long uid = (Long) authentication.getPrincipal();
        limiter.check("oauthunlink:user:" + uid, 10, Duration.ofHours(1));
        oauth.unlink(uid, parse(provider));
        return new LinkResponse(false);
    }

    @GetMapping("/identities")
    public List<OAuthService.IdentityView> identities(Authentication authentication) {
        oauth.requireEnabled();
        Long uid = (Long) authentication.getPrincipal();
        limiter.check("oauthids:user:" + uid, 30, Duration.ofMinutes(1));
        return oauth.identitiesOf(uid);
    }

    private static OAuthProvider parse(String raw) {
        OAuthProvider p = OAuthProvider.parse(raw);
        if (p == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz sağlayıcı.");
        }
        return p;
    }
}
