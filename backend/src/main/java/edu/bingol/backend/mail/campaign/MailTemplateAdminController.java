package edu.bingol.backend.mail.campaign;

import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.mail.campaign.MailAdminDtos.DraftPreviewRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.PreviewView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.StoredPreviewRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.TemplateRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.TemplateRow;
import edu.bingol.backend.mail.campaign.MailAdminDtos.TemplateView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.TestSendRequest;
import edu.bingol.backend.mail.campaign.MailAdminDtos.TestSendView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.VariablesView;
import edu.bingol.backend.mail.campaign.MailAdminDtos.VersionRow;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici e-posta sablonlari (/api/admin/mail/**, yalniz ADMIN; yazma islemleri denetim kaydina dusar).
 * Yazma/onizleme/test icin JWT ile giris gerekir (Basic auth yonetici kimligi tasimaz).
 */
@RestController
@RequestMapping("/api/admin/mail")
public class MailTemplateAdminController {

    private final MailTemplateAdminService service;
    private final RateLimiter limiter;

    public MailTemplateAdminController(MailTemplateAdminService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping("/variables")
    public VariablesView variables() {
        return service.variables();
    }

    @GetMapping("/templates")
    public PageResponse<TemplateRow> list(@RequestParam(required = false) MailCustomTemplate.Status status,
                                          @RequestParam(required = false) String q,
                                          @RequestParam(defaultValue = "0") int page,
                                          @RequestParam(defaultValue = "20") int size) {
        return service.list(status, q, page, size);
    }

    @GetMapping("/templates/{id}")
    public TemplateView get(@PathVariable Long id) {
        return service.get(id);
    }

    @GetMapping("/templates/{id}/versions")
    public List<VersionRow> versions(@PathVariable Long id) {
        return service.versions(id);
    }

    @PostMapping("/templates")
    @ResponseStatus(HttpStatus.CREATED)
    public TemplateView create(@Valid @RequestBody TemplateRequest r) {
        Long admin = CurrentUser.id();
        limiter.check("mailtpl:write:" + admin, 60, Duration.ofHours(1));
        return service.create(admin, r);
    }

    @PutMapping("/templates/{id}")
    public TemplateView update(@PathVariable Long id, @Valid @RequestBody TemplateRequest r) {
        Long admin = CurrentUser.id();
        limiter.check("mailtpl:write:" + admin, 60, Duration.ofHours(1));
        return service.update(admin, id, r);
    }

    @PostMapping("/templates/{id}/publish")
    public TemplateView publish(@PathVariable Long id) {
        limiter.check("mailtpl:state:" + CurrentUser.id(), 60, Duration.ofHours(1));
        return service.publish(id);
    }

    @PostMapping("/templates/{id}/archive")
    public TemplateView archive(@PathVariable Long id) {
        limiter.check("mailtpl:state:" + CurrentUser.id(), 60, Duration.ofHours(1));
        return service.archive(id);
    }

    @DeleteMapping("/templates/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        limiter.check("mailtpl:state:" + CurrentUser.id(), 60, Duration.ofHours(1));
        service.delete(id);
    }

    /** Kaydedilmemis icerigi onizleme (editor canli onizleme). */
    @PostMapping("/templates/preview")
    public PreviewView previewDraft(@Valid @RequestBody DraftPreviewRequest r) {
        limiter.check("mailtpl:preview:" + CurrentUser.id(), 240, Duration.ofHours(1));
        return service.previewDraft(r.lang(), r.content());
    }

    @PostMapping("/templates/{id}/preview")
    public PreviewView preview(@PathVariable Long id, @RequestBody(required = false) StoredPreviewRequest r) {
        limiter.check("mailtpl:preview:" + CurrentUser.id(), 240, Duration.ofHours(1));
        return service.previewStored(id, r == null ? null : r.lang(), r == null ? null : r.version());
    }

    /** Test e-postasi: yalnizca isteyen yoneticinin kendi adresine; saatte 10. */
    @PostMapping("/templates/{id}/test")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public TestSendView test(@PathVariable Long id, @RequestBody(required = false) TestSendRequest r) {
        Long admin = CurrentUser.id();
        limiter.check("mailtpl:test:" + admin, 10, Duration.ofHours(1));
        return service.test(admin, id, r == null ? null : r.lang());
    }
}
