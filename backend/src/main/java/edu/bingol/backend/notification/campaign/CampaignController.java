package edu.bingol.backend.notification.campaign;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.notification.campaign.CampaignDtos.Audience;
import edu.bingol.backend.notification.campaign.CampaignDtos.AudienceCount;
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

    /** Kampanya olustur (hemen veya zamanlanmis). Gonderim arka planda yapilir; saatte en fazla 20 kampanya. */
    @PostMapping("/campaigns")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public CampaignView create(@Valid @RequestBody CreateCampaignRequest r) {
        Long admin = CurrentUser.id();
        limiter.check("campaign:admin:" + admin, 20, Duration.ofHours(1));
        return CampaignView.of(campaigns.create(admin, r));
    }

    @GetMapping("/campaigns")
    public CampaignPage list(@RequestParam(required = false) Long cursor, @RequestParam(defaultValue = "20") int size) {
        return campaigns.list(cursor, size);
    }

    @GetMapping("/campaigns/{id}")
    public CampaignView get(@PathVariable Long id) {
        return CampaignView.of(campaigns.get(id));
    }

    @PostMapping("/campaigns/{id}/cancel")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(@PathVariable Long id) {
        campaigns.cancel(id);
    }
}
