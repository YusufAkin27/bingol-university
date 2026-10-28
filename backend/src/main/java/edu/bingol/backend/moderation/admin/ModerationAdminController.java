package edu.bingol.backend.moderation.admin;

import edu.bingol.backend.moderation.ModerationTargetState;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.moderation.admin.ModAdminDtos.ForgiveRequest;
import edu.bingol.backend.moderation.admin.ModAdminDtos.ForgiveResult;
import edu.bingol.backend.moderation.admin.ModAdminDtos.HiddenRow;
import edu.bingol.backend.moderation.admin.ModAdminDtos.PageResult;
import edu.bingol.backend.moderation.admin.ModAdminDtos.RestoreRequest;
import edu.bingol.backend.moderation.admin.ModAdminDtos.RestoreResult;
import edu.bingol.backend.moderation.admin.ModAdminDtos.StrikeRow;
import edu.bingol.backend.moderation.admin.ModAdminDtos.TemplatePage;
import edu.bingol.backend.moderation.admin.ModAdminDtos.TemplateRequest;
import edu.bingol.backend.moderation.admin.ModAdminDtos.TemplateView;
import edu.bingol.backend.moderation.admin.ModAdminDtos.UserStrikes;
import edu.bingol.backend.common.ApiException;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.Locale;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
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
 * Moderasyon tamamlama (P11; `/api/admin/**` yalniz ADMIN): ihlal listesi + af, gizlenen icerik birlesik listesi +
 * geri alma, sebep sablonu yonetimi. Af ve geri alma SEBEP ister (AdminGuardPolicy), AuditContext ile denetlenir.
 * Eski `GET /api/admin/reports/reason-templates` ayni bicimde calismaya devam eder.
 */
@RestController
@RequestMapping("/api/admin")
public class ModerationAdminController {

    private final StrikeAdminService strikes;
    private final HiddenContentAdminService hidden;
    private final ReasonTemplateService templates;

    public ModerationAdminController(StrikeAdminService strikes, HiddenContentAdminService hidden,
                                     ReasonTemplateService templates) {
        this.strikes = strikes;
        this.hidden = hidden;
        this.templates = templates;
    }

    // --- strike ---

    /** status=ACTIVE|REVOKED|ALL (varsayilan ALL); from/to gun (yyyy-MM-dd, Europe/Istanbul, to dahil). */
    @GetMapping("/moderation/strikes")
    public PageResult<StrikeRow> strikes(@RequestParam(required = false) Long userId,
                                         @RequestParam(required = false) ReportTargetType targetType,
                                         @RequestParam(required = false) Report.Resolution resolution,
                                         @RequestParam(required = false) String status,
                                         @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                         @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                         @RequestParam(defaultValue = "0") int page,
                                         @RequestParam(defaultValue = "20") int size) {
        return strikes.list(userId, targetType, resolution, status, AdminDates.from(from), AdminDates.toExclusive(to),
                page, size);
    }

    @GetMapping("/users/{id}/strikes")
    public UserStrikes userStrikes(@PathVariable Long id) {
        return strikes.ofUser(id);
    }

    /** Af: sebep zorunlu (govdede `reason`); kullaniciya bildirim gider, sayac duser. */
    @PostMapping("/moderation/strikes/{id}/forgive")
    public ForgiveResult forgive(@PathVariable Long id, @Valid @RequestBody ForgiveRequest r, Authentication auth) {
        return strikes.forgive(id, adminId(auth), r.reason());
    }

    // --- gizlenen icerik ---

    @GetMapping("/moderation/hidden")
    public PageResult<HiddenRow> hidden(@RequestParam(required = false) ReportTargetType targetType,
                                        @RequestParam(required = false) ModerationTargetState.HiddenBy hiddenBy,
                                        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                        @RequestParam(defaultValue = "0") int page,
                                        @RequestParam(defaultValue = "20") int size) {
        return hidden.list(targetType, hiddenBy, AdminDates.from(from), AdminDates.toExclusive(to), page, size);
    }

    /** Geri al: yalniz `reversible()` turler; sebep zorunlu. */
    @PostMapping("/moderation/hidden/{type}/{id}/restore")
    public RestoreResult restore(@PathVariable String type, @PathVariable Long id,
                                 @Valid @RequestBody RestoreRequest r) {
        ReportTargetType t;
        try {
            t = ReportTargetType.valueOf(type.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TARGET_TYPE_UNSUPPORTED", "Bu tür henüz raporlanamıyor.");
        }
        return hidden.restore(t, id, r.reason());
    }

    // --- sebep sablonlari ---

    @GetMapping("/moderation/reason-templates")
    public TemplatePage templates() {
        return templates.list();
    }

    @PostMapping("/moderation/reason-templates")
    @ResponseStatus(HttpStatus.CREATED)
    public TemplateView createTemplate(@Valid @RequestBody TemplateRequest r) {
        return templates.create(r);
    }

    @PutMapping("/moderation/reason-templates/{id}")
    public TemplateView updateTemplate(@PathVariable Long id, @Valid @RequestBody TemplateRequest r) {
        return templates.update(id, r);
    }

    @DeleteMapping("/moderation/reason-templates/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteTemplate(@PathVariable Long id) {
        templates.delete(id);
    }

    /** Basic auth ile giren yonetici icin principal Long degildir; kimlik bos kalir. */
    static Long adminId(Authentication auth) {
        return auth != null && auth.getPrincipal() instanceof Long l ? l : null;
    }
}
