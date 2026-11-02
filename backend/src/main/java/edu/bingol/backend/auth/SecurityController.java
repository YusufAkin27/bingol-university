package edu.bingol.backend.auth;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Hesap guvenligi eylemleri (bildirim kartindaki "Bu ben degilim"). Kimlik dogrulamasi sarttir. */
@RestController
@RequestMapping("/api/security")
public class SecurityController {

    /** Genel yanit: islemin ne yaptigini sezdirmez; istemci sifre sifirlama ekranina yonlendirir. */
    public record NotMeResponse(boolean ok, boolean resetPasswordRecommended) {}

    private final NotMeService service;
    private final RateLimiter limiter;

    public SecurityController(NotMeService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /**
     * "Bu ben degilim": hesabin TUM oturumlari (bu cihaz dahil) ve guvenilen 2FA cihazlari kapanir, olay denetim
     * kaydina yazilir. Cevap her zaman ayni ({@code ok=true, resetPasswordRecommended=true}); istemci kullaniciyi
     * "Sifremi sifirla" akisina (forgot-password) yonlendirir. Saatte 5 deneme (hesap basina).
     */
    @PostMapping("/not-me")
    public NotMeResponse notMe(HttpServletRequest http) {
        Long uid = CurrentUser.id();
        limiter.check("sec-notme:" + uid, 5, Duration.ofHours(1));
        service.notMe(uid, http);
        return new NotMeResponse(true, true);
    }
}
