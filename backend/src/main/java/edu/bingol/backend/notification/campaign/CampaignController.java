package edu.bingol.backend.notification.campaign;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.notification.campaign.CampaignDtos.Audience;
import edu.bingol.backend.notification.campaign.CampaignDtos.AudienceCount;
import edu.bingol.backend.notification.campaign.CampaignDtos.AudiencePreview;
import edu.bingol.backend.notification.campaign.CampaignDtos.PreviewRequest;
import edu.bingol.backend.notification.campaign.CampaignDtos.SendRequest;
import edu.bingol.backend.notification.campaign.CampaignDtos.CampaignPage;
import edu.bingol.backend.notification.campaign.CampaignDtos.CampaignView;
import edu.bingol.backend.notification.campaign.CampaignDtos.CreateCampaignRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Mobil yonetici ekrani icin push kampanya uclari (/api/admin/** => ROLE_ADMIN).
 * Kampanyayi olusturan yoneticinin kimligi gerekir: JWT ile giris yapilmalidir (Basic auth yetmez).
 */
@RestController
@RequestMapping("/api/admin/push")
public class CampaignController {

    private final CampaignService campaigns;
    private final RateLimiter limiter;

    public CampaignController(CampaignService campaigns, RateLimiter limiter) {
        this.campaigns = campaigns;
        this.limiter = limiter;
    }

    /** Hedef kitle onizleme: kac kisiye gidecek? */
    @PostMapping("/audience-count")
    public AudienceCount audienceCount(@Valid @RequestBody Audience audience) {
        return new AudienceCount(campaigns.count(CurrentUser.id(), audience));
    }

    /** Kitle onizleme (tekil sayi, tercihle atlananlar, dil kirilimi, ornek kisiler, bulunamayan girdiler). */
    @PostMapping("/audience/preview")
    public AudiencePreview preview(@Valid @RequestBody PreviewRequest r) {
        Long admin = CurrentUser.id();
        limiter.check("campaign:preview:" + admin, 120, Duration.ofMinutes(1));
        return campaigns.preview(admin, r.audience(), r.type());
    }

    /** Test gonderimi: yalnizca yoneticinin kendisine, hemen. Saatte en fazla 30. */
    @PostMapping("/campaigns/test")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public CampaignView test(@Valid @RequestBody SendRequest r) {
        Long admin = CurrentUser.id();
        limiter.check("campaign:test:" + admin, 30, Duration.ofHours(1));
        return CampaignView.of(campaigns.createTest(admin, r));
    }

    /** Hizli gonderim: tek kullaniciya hemen (kullanici detay sayfasi). Saatte en fazla 60. */
    @PostMapping("/users/{userId}/send")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public CampaignView sendToUser(@PathVariable Long userId, @Valid @RequestBody SendRequest r) {
        Long admin = CurrentUser.id();
        limiter.check("campaign:quick:" + admin, 60, Duration.ofHours(1));
        return CampaignView.of(campaigns.createQuick(admin, userId, r));
    }

    /** Kampanya olustur (hemen veya zamanlanmis). Gonderim arka planda yapilir; saatte en fazla 20 kampanya. */
    @PostMapping("/campaigns")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public CampaignView create(@Valid @RequestBody CreateCampaignRequest r) {
        Long admin = CurrentUser.id();
        limiter.check("campaign:admin:" + admin, 20, Duration.ofHours(1));
        return CampaignView.of(campaigns.create(admin, r));
    }

    @GetMapping("/campaigns")
    public CampaignPage list(@RequestParam(required = false) Long cursor, @RequestParam(defaultValue = "20") int size,
                             @RequestParam(required = false) PushCampaign.Status status) {
        return campaigns.list(cursor, size, status);
    }

    @GetMapping("/campaigns/{id}")
    public CampaignView get(@PathVariable Long id) {
        return CampaignView.of(campaigns.get(id));
    }

    @PostMapping("/campaigns/{id}/cancel")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(@PathVariable Long id) {
        limiter.check("campaign:ctl:" + CurrentUser.id(), 60, Duration.ofMinutes(1));
        campaigns.cancel(id);
    }

    @PostMapping("/campaigns/{id}/pause")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void pause(@PathVariable Long id) {
        limiter.check("campaign:ctl:" + CurrentUser.id(), 60, Duration.ofMinutes(1));
        campaigns.pause(id);
    }

    @PostMapping("/campaigns/{id}/resume")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void resume(@PathVariable Long id) {
        limiter.check("campaign:ctl:" + CurrentUser.id(), 60, Duration.ofMinutes(1));
        campaigns.resume(id);
    }
}
