package edu.bingol.backend.auth.realemail;

import edu.bingol.backend.auth.oauth.OAuthProvider;
import edu.bingol.backend.auth.realemail.RealEmailDtos.StartRequest;
import edu.bingol.backend.auth.realemail.RealEmailDtos.StartResponse;
import edu.bingol.backend.auth.realemail.RealEmailDtos.VerifyRequest;
import edu.bingol.backend.auth.realemail.RealEmailDtos.VerifyResponse;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.Locale;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Gercek e-posta uclari (KIMLIKLI). Is kurallari {@link RealEmailService}'te; burada yalniz hiz siniri + HTTP eslemesi.
 * Kapi ({@link RealEmailRequiredWriteFilter}) ve profil kapisi bu yollara dokunmaz (serbest).
 */
@RestController
@RequestMapping("/api/users/me/email")
public class RealEmailController {

    private final RealEmailService service;
    private final RateLimiter limiter;
    private final ClientIp clientIp;

    public RealEmailController(RealEmailService service, RateLimiter limiter, ClientIp clientIp) {
        this.service = service;
        this.limiter = limiter;
        this.clientIp = clientIp;
    }

    /** Adrese 6 haneli kod gonderir (kullanici basina saatte 5, hedef adres basina saatte 5, IP basina saatte 30). */
    @PostMapping("/start")
    public StartResponse start(@Valid @RequestBody StartRequest r, HttpServletRequest http) {
        Long uid = CurrentUser.id();
        limiter.check("realemail:start:user:" + uid, 5, Duration.ofHours(1));
        limiter.check("realemail:start:ip:" + clientIp.limitKey(http), 30, Duration.ofHours(1));
        if (r.email() != null) {
            // Ayni hedefe (baskasinin posta kutusuna) dagitik kod yagdirmayi engeller; ozet: adres log/anahtarda acik kalmaz
            limiter.check("realemail:start:target:" + Hashing.sha256(r.email().trim().toLowerCase(Locale.ROOT)),
                    5, Duration.ofHours(1));
        }
        OAuthProvider reauth = r.reauthProvider() == null ? null : OAuthProvider.parse(r.reauthProvider());
        return service.start(uid, r.email(), r.password(), reauth, r.reauthToken(), r.reauthNonce());
    }

    /** Kodu dogrular (kullanici basina 15 dk'da 20; kod basina 5 deneme VerificationService'te). */
    @PostMapping("/verify")
    public VerifyResponse verify(@Valid @RequestBody VerifyRequest r, HttpServletRequest http) {
        Long uid = CurrentUser.id();
        limiter.check("realemail:verify:user:" + uid, 20, Duration.ofMinutes(15));
        String ip = clientIp.limitKey(http);
        limiter.check("realemail:verify:ip:" + ip, 60, Duration.ofMinutes(15));
        return service.verify(uid, r.code(), ip);
    }
}
