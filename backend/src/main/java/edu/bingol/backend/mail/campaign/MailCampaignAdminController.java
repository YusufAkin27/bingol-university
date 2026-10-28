package edu.bingol.backend.mail.campaign;

import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.mail.campaign.MailAdminDtos.AudiencePreview;
import edu.bingol.backend.mail.campaign.MailAdminDtos.AudiencePreviewRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.CampaignRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.CampaignView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.RecipientRow;
import edu.bingol.backend.mail.campaign.MailAdminDtos.ScheduleRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Yonetici mail kampanyalari (/api/admin/mail/campaigns, yalniz ADMIN; yazma islemleri denetim kaydina dusar). */
@RestController
@RequestMapping("/api/admin/mail/campaigns")
public class MailCampaignAdminController {

    private final MailCampaignAdminService service;
    private final RateLimiter limiter;

    public MailCampaignAdminController(MailCampaignAdminService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping
    public PageResponse<CampaignView> list(@RequestParam(required = false) MailCampaign.Status status,
                                           @RequestParam(required = false) String q,
                                           @RequestParam(defaultValue = "0") int page,
                                           @RequestParam(defaultValue = "20") int size) {
        return service.list(status, q, page, size);
    }

    @GetMapping("/{id}")
    public CampaignView get(@PathVariable Long id) {
        return service.get(id);
    }

    /** Hata/atlanan alici listesi (adres maskeli); status ile suzulur. */
    @GetMapping("/{id}/recipients")
    public PageResponse<RecipientRow> recipients(@PathVariable Long id,
                                                 @RequestParam(required = false) MailCampaignRecipient.Status status,
                                                 @RequestParam(defaultValue = "0") int page,
                                                 @RequestParam(defaultValue = "50") int size) {
        return service.recipients(id, status, page, size);
    }

    /** Hedef kitle onizleme: kac kisiye gidecek, kac atlanacak, dil dagilimi. */
    @PostMapping("/audience/preview")
    public AudiencePreview audiencePreview(@Valid @RequestBody AudiencePreviewRequest r) {
        limiter.check("mailcmp:preview:" + CurrentUser.id(), 120, Duration.ofHours(1));
        return service.previewAudience(r);
    }

    /** Kampanya kaydi (TASLAK). requestKey ayni ise ayni kampanya doner (cift tiklama korumasi). */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CampaignView create(@Valid @RequestBody CampaignRequest r) {
        Long admin = CurrentUser.id();
        limiter.check("mailcmp:create:" + admin, 30, Duration.ofHours(1));
        return service.create(admin, r);
    }

    @PutMapping("/{id}")
    public CampaignView update(@PathVariable Long id, @Valid @RequestBody CampaignRequest r) {
        limiter.check("mailcmp:create:" + CurrentUser.id(), 60, Duration.ofHours(1));
        return service.update(id, r);
    }

    /** Zamanla/gonder: scheduledAt bos veya gecmis ise hemen. Gonderim arka planda (202). */
    @PostMapping("/{id}/schedule")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public CampaignView schedule(@PathVariable Long id, @RequestBody(required = false) ScheduleRequest r) {
        limiter.check("mailcmp:schedule:" + CurrentUser.id(), 20, Duration.ofHours(1));
        return service.schedule(id, r == null ? null : r.scheduledAt());
    }

    @PostMapping("/{id}/cancel")
    public CampaignView cancel(@PathVariable Long id) {
        limiter.check("mailcmp:state:" + CurrentUser.id(), 60, Duration.ofHours(1));
        return service.cancel(id);
    }

    @PostMapping("/{id}/pause")
    public CampaignView pause(@PathVariable Long id) {
        limiter.check("mailcmp:state:" + CurrentUser.id(), 60, Duration.ofHours(1));
        return service.pause(id);
    }

    @PostMapping("/{id}/resume")
    public CampaignView resume(@PathVariable Long id) {
        limiter.check("mailcmp:state:" + CurrentUser.id(), 60, Duration.ofHours(1));
        return service.resume(id);
    }
}
