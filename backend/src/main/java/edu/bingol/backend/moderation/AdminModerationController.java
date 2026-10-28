package edu.bingol.backend.moderation;

import edu.bingol.backend.admin.chat.AdminReportContextService;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.moderation.dto.ModerationDtos.BulkResolveRequest;
import edu.bingol.backend.moderation.dto.ModerationDtos.BulkResult;
import edu.bingol.backend.moderation.dto.ModerationDtos.ReasonTemplate;
import edu.bingol.backend.moderation.dto.ModerationDtos.ReportQueue;
import edu.bingol.backend.moderation.dto.ModerationDtos.ReportView;
import edu.bingol.backend.moderation.dto.ModerationDtos.ResolveRequest;
import edu.bingol.backend.moderation.dto.ModerationDtos.Stats;
import edu.bingol.backend.moderation.dto.ModerationDtos.SuspendRequest;
import edu.bingol.backend.news.NewsRepository;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.Slice;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Yonetici uclari (/api/admin/** zaten SecurityConfig'te ROLE_ADMIN ister). Yazma uclari AuditInterceptor ile denetlenir. */
@RestController
@RequestMapping("/api/admin")
public class AdminModerationController {

    private final ReportService reports;
    private final ReportRepository reportRepo;
    private final UserModerationService userModeration;
    private final UserRepository users;
    private final NewsRepository news;
    private final RateLimiter limiter;
    private final I18n i18n;
    private final AdminReportContextService context;
    /** Yonetilebilir sebep sablonlari (P11); yoksa sabit liste. */
    private edu.bingol.backend.moderation.admin.ReasonTemplateService templates;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setTemplates(edu.bingol.backend.moderation.admin.ReasonTemplateService templates) {
        this.templates = templates;
    }

    public AdminModerationController(ReportService reports, ReportRepository reportRepo,
                                     UserModerationService userModeration, UserRepository users, NewsRepository news,
                                     RateLimiter limiter, I18n i18n,
                                     AdminReportContextService context) {
        this.reports = reports;
        this.reportRepo = reportRepo;
        this.userModeration = userModeration;
        this.users = users;
        this.news = news;
        this.limiter = limiter;
        this.i18n = i18n;
        this.context = context;
    }

    /**
     * GET /api/admin/reports?status=OPEN&order=asc|desc|priority&targetType=&cursor=&size=20
     * asc/desc: id imecli. priority: oncelik (yuksekten dusuge); bu modda cursor SAYFA NUMARASIDIR (0'dan).
     * Her satirda priority, preview, hidden/hiddenBy, openReporters bulunur.
     */
    @GetMapping("/reports")
    public ReportQueue queue(@RequestParam(defaultValue = "OPEN") Report.Status status,
                             @RequestParam(defaultValue = "asc") String order,
                             @RequestParam(required = false) ReportTargetType targetType,
                             @RequestParam(required = false) Long cursor,
                             @RequestParam(defaultValue = "20") int size) {
        int s = CursorPage.clampSize(size);
        if ("priority".equalsIgnoreCase(order)) {
            int page = cursor == null ? 0 : (int) Math.min(cursor, 100_000L);
            Slice<Report> slice = reports.queueByPriority(status, targetType, page, s);
            List<ReportView> items = slice.getContent().stream().map(r -> ReportView.of(r, reports.enrich(r))).toList();
            return new ReportQueue(context.decorate(items), slice.hasNext() ? (long) page + 1 : null);
        }
        List<Report> rows = reports.queue(status, targetType, cursor, s, "desc".equalsIgnoreCase(order));
        CursorPage<ReportView> page = CursorPage.of(rows, s, Report::getId, r -> ReportView.of(r, reports.enrich(r)));
        return new ReportQueue(context.decorate(page.items()), page.nextCursor());
    }

    @PostMapping("/reports/{id}/resolve")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void resolve(@PathVariable Long id, @Valid @RequestBody ResolveRequest r, Authentication auth) {
        reports.resolve(id, adminId(auth), r.action(), r.message(), r.reasonCode());
    }

    /** Toplu karar (en fazla 100). Hata veren satir digerlerini durdurmaz; sonuc satir satir doner. */
    @PostMapping("/reports/bulk-resolve")
    public List<BulkResult> bulkResolve(@Valid @RequestBody BulkResolveRequest r, Authentication auth) {
        Long adminId = adminId(auth);
        requireValidReason(r.reasonCode());
        limiter.check("modbulk:" + (adminId == null ? "basic" : adminId), 20, Duration.ofMinutes(1));
        List<BulkResult> out = new ArrayList<>();
        for (Long id : r.ids()) {
            try {
                reports.resolve(id, adminId, r.action(), r.message(), r.reasonCode());
                out.add(new BulkResult(id, true, null));
            } catch (ApiException e) {
                out.add(new BulkResult(id, false, e.code()));
            }
        }
        return out;
    }

    /** Karar nedeni sablonlari (istek dilinde `text` + uc dilde `texts`). */
    @GetMapping("/reports/reason-templates")
    public List<ReasonTemplate> reasonTemplates() {
        if (templates != null) {
            return templates.activeForResolve();
        }
        List<ReasonTemplate> out = new ArrayList<>();
        for (DecisionReason r : DecisionReason.values()) {
            Map<String, String> texts = new LinkedHashMap<>();
            for (Lang l : Lang.values()) {
                texts.put(l.code(), i18n.msg(r.messageKey(), l));
            }
            out.add(new ReasonTemplate(r.name(), i18n.current(r.messageKey()), texts));
        }
        return out;
    }

    @PostMapping("/users/{id}/suspend")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void suspend(@PathVariable Long id, @Valid @RequestBody SuspendRequest r) {
        userModeration.suspend(id, r.reason());
    }

    @PostMapping("/users/{id}/unsuspend")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unsuspend(@PathVariable Long id) {
        userModeration.unsuspend(id);
    }

    @GetMapping("/stats")
    public Stats stats() {
        return new Stats(users.count(), users.countByStatus(UserStatus.ACTIVE), users.countByStatus(UserStatus.SUSPENDED),
                reportRepo.countByStatus(Report.Status.OPEN), news.count());
    }

    /** Toplu islemde gecersiz kod her satirda ayni hatayi uretmesin: bastan 400. */
    private void requireValidReason(String code) {
        if (code != null && !code.isBlank() && (templates != null ? templates.validCode(code).isEmpty()
                : DecisionReason.parse(code).isEmpty())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_CODE_INVALID", "Geçersiz karar nedeni kodu.");
        }
    }

    /** Basic auth ile giren yonetici icin principal Long degildir; karar veren id'si bos kalir. */
    static Long adminId(Authentication auth) {
        return auth != null && auth.getPrincipal() instanceof Long l ? l : null;
    }
}
