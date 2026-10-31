package edu.bingol.backend.profile.privacy;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.profile.privacy.PrivacyDtos.PrivacyView;
import edu.bingol.backend.profile.privacy.PrivacyDtos.UpdatePrivacyRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users/me/privacy")
public class PrivacyController {

    /** Gizli hesap anahtarı: saatte en çok bu kadar DEĞİŞİKLİK (aç-kapa ile bildirim/takip kötüye kullanımı). */
    static final int PRIVATE_FLIPS_PER_HOUR = 10;

    private final PrivacyService privacy;
    private final RateLimiter limiter;

    public PrivacyController(PrivacyService privacy, RateLimiter limiter) {
        this.privacy = privacy;
        this.limiter = limiter;
    }

    @GetMapping
    public PrivacyView get() {
        return PrivacyView.of(privacy.get(CurrentUser.id()));
    }

    /** PUT ve PATCH aynı işi yapar (verilmeyen alan değişmez). */
    @RequestMapping(method = {RequestMethod.PUT, RequestMethod.PATCH})
    public PrivacyView update(@Valid @RequestBody UpdatePrivacyRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("profile-privacy:user:" + uid, 30, Duration.ofHours(1));
        // Hesap türü yalnız GERÇEKTEN değişirken sayılır (aynı değeri tekrar göndermek hak yemez)
        if (r.privateAccount() != null && r.privateAccount() != privacy.get(uid).isPrivateAccount()) {
            limiter.check("profile-private-flip:user:" + uid, PRIVATE_FLIPS_PER_HOUR, Duration.ofHours(1));
            limiter.check("profile-private-flip-burst:user:" + uid, 3, Duration.ofMinutes(1)); // kısa bekleme
        }
        return PrivacyView.of(privacy.update(uid, r));
    }
}
