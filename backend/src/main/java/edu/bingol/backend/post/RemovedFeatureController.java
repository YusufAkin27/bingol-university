package edu.bingol.backend.post;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Sade Kesfet sozlesmesiyle kaldirilan kullanici uclari: kalici 410 Gone {@code FEATURE_REMOVED}.
 * Neden 404 degil: eski surum mobil istemciler bu yollari hala cagirabilir; 410 "bu ozellik bilerek kaldirildi"
 * demektir, istemci hata olarak yeniden denemez ve guncelleme uyarisi gosterebilir. Veri tablolari korunur
 * (yorum, hikaye, kaydedilenler, etiketler); yonetici moderasyon uclari (/api/admin/**) ve KVKK disa aktarimi aynen calisir.
 */
@RestController
public class RemovedFeatureController {

    private final RateLimiter limiter;

    public RemovedFeatureController(RateLimiter limiter) {
        this.limiter = limiter;
    }

    @RequestMapping({
            // yorumlar
            "/api/posts/{id}/comments", "/api/comments/{id}", "/api/comments/{id}/replies",
            // hikayeler
            "/api/stories", "/api/stories/**", "/api/users/{id}/stories",
            // etiket / bahsetme
            "/api/hashtags/**", "/api/users/mention-suggest",
            // kaydet ve begenenler listesi
            "/api/posts/{id}/save", "/api/posts/saved", "/api/posts/{id}/likes"})
    public void gone() {
        Long uid = CurrentUser.id();
        limiter.check("removed:" + uid, 120, Duration.ofMinutes(1));
        throw new ApiException(HttpStatus.GONE, "FEATURE_REMOVED", "Bu özellik kaldırıldı.");
    }
}
