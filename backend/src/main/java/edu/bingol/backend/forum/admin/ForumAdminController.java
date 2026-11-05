package edu.bingol.backend.forum.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.forum.admin.ForumAdminDtos.ActionItem;
import edu.bingol.backend.forum.admin.ForumAdminDtos.AdminPage;
import edu.bingol.backend.forum.admin.ForumAdminDtos.ReportItem;
import edu.bingol.backend.forum.admin.ForumAdminDtos.TopicItem;
import edu.bingol.backend.forum.moderation.ForumModerationService;
import edu.bingol.backend.forum.moderation.ForumModerationService.Action;
import edu.bingol.backend.forum.moderation.ForumModerationService.Result;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportRepository;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.moderation.ReportTargetType;
import edu.bingol.backend.moderation.dto.ModerationDtos.ResolveRequest;
import edu.bingol.backend.forum.admin.ForumAdminCategoryService.CategoryInput;
import edu.bingol.backend.forum.admin.ForumAdminCategoryService.CategoryView;
import java.util.List;
import java.util.Map;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetim paneli forum uclari ({@code /api/admin/forum/**}; ROLE_ADMIN + {@code AdminPermissionPolicy}: okuma
 * {@code forum.read}, moderasyon {@code forum.moderate}, kategori yazma {@code forum.categories}). Her yazma
 * {@code admin_audit} kaydi uretir (AuditInterceptor; hedef + gerekce burada bildirilir) ve
 * {@code forum_moderation_action} satiri yazar. Listeler sayfa tabanlidir; kimlik: ANONIM icerikte yazar yoktur.
 */
@RestController
@RequestMapping("/api/admin/forum")
public class ForumAdminController {

    public record ModerateRequest(@NotNull Action action, @Size(max = 300) String reason) {}

    private final ForumAdminQueryService queries;
    private final ForumModerationService moderation;
    private final ReportService reportService;
    private final ReportRepository reportRepository;
    private final ForumAdminCategoryService categories;

    public ForumAdminController(ForumAdminQueryService queries, ForumModerationService moderation,
                                ReportService reportService, ReportRepository reportRepository,
                                ForumAdminCategoryService categories) {
        this.queries = queries;
        this.moderation = moderation;
        this.reportService = reportService;
        this.reportRepository = reportRepository;
        this.categories = categories;
    }

    // --- kategoriler (forum.categories) ---

    /** Arsivdekiler dahil tum kategoriler (sort_order sirasiyla), konu sayilariyla. Yanit duz dizi. */
    @GetMapping("/categories")
    public List<CategoryView> listCategories() {
        return categories.list();
    }

    @PostMapping("/categories")
    @ResponseStatus(HttpStatus.CREATED)
    public CategoryView createCategory(@RequestBody CategoryInput in) {
        CategoryView v = categories.create(in);
        AuditContext.target("FORUM_CATEGORY", v.id()).summary("forum kategori olusturuldu: " + v.slug());
        return v;
    }

    @PatchMapping("/categories/{id}")
    public CategoryView updateCategory(@PathVariable Long id, @RequestBody CategoryInput in) {
        AuditContext.target("FORUM_CATEGORY", id).summary("forum kategori guncellendi");
        return categories.update(id, in);
    }

    /** DELETE = arsivle (active=false); kategori ve konulari silinmez. */
    @DeleteMapping("/categories/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void archiveCategory(@PathVariable Long id) {
        AuditContext.target("FORUM_CATEGORY", id).summary("forum kategori arsivlendi");
        categories.archive(id);
    }

    public record ReorderRequest(List<Long> ids) {}

    /** Verilen sirayi uygular (listede olmayanlar sona); guncel listeyi doner. */
    @PostMapping("/categories/reorder")
    public List<CategoryView> reorderCategories(@RequestBody ReorderRequest r) {
        AuditContext.target("FORUM_CATEGORY", null).summary("forum kategori sirasi guncellendi");
        return categories.reorder(r.ids());
    }

    /**
     * status=OPEN|RESOLVED|ALL (varsayilan OPEN), type=FORUM_TOPIC|FORUM_COMMENT, reason=SPAM|HARASSMENT|INAPPROPRIATE|
     * PERSONAL_INFO|OTHER; cursor (= sonraki sayfa) ya da page.
     */
    @GetMapping("/reports")
    public AdminPage<ReportItem> reports(@RequestParam(required = false) String status,
                                         @RequestParam(required = false) String type,
                                         @RequestParam(required = false) String reason,
                                         @RequestParam(required = false) String cursor,
                                         @RequestParam(required = false) Integer page,
                                         @RequestParam(defaultValue = "20") int size) {
        return queries.reports(status, type, reason, pageOf(cursor, page), size);
    }

    @GetMapping("/actions")
    public AdminPage<ActionItem> actions(@RequestParam(required = false) String targetType,
                                         @RequestParam(required = false) String action,
                                         @RequestParam(required = false) String cursor,
                                         @RequestParam(required = false) Integer page,
                                         @RequestParam(defaultValue = "20") int size) {
        return queries.actions(targetType, action, pageOf(cursor, page), size);
    }

    @GetMapping("/topics")
    public AdminPage<TopicItem> topics(@RequestParam(required = false) String q,
                                       @RequestParam(required = false) String status,
                                       @RequestParam(required = false) Long categoryId,
                                       @RequestParam(required = false) Integer page,
                                       @RequestParam(defaultValue = "20") int size) {
        return queries.topics(q, status, categoryId, page == null ? 0 : page, size);
    }

    @PostMapping("/topics/{id}/moderate")
    public Result moderateTopic(@PathVariable Long id, @Valid @RequestBody ModerateRequest r, Authentication auth) {
        AuditContext.target("FORUM_TOPIC", id).reason(r.reason()).summary("forum konu: " + r.action());
        return moderation.moderateTopic(adminId(auth), id, r.action(), r.reason());
    }

    @PostMapping("/comments/{id}/moderate")
    public Result moderateComment(@PathVariable Long id, @Valid @RequestBody ModerateRequest r, Authentication auth) {
        AuditContext.target("FORUM_COMMENT", id).reason(r.reason()).summary("forum yorum: " + r.action());
        return moderation.moderateComment(adminId(auth), id, r.action(), r.reason());
    }

    /**
     * Forum sikayetini sonuclandirir (mevcut {@code /api/admin/reports/{id}/resolve} ile ayni karar kumesi; yalniz FORUM_*
     * sikayetleri): DISMISS (yoksay; otomatik gizlenmisse geri acar), WARN, HIDE (icerigi kaldirir), SUSPEND_USER.
     * Karar hedefin TUM acik sikayetlerini kapatir. Gerekce: {@code X-Admin-Reason} basligi ya da govdede {@code reason}.
     */
    @PostMapping("/reports/{id}/resolve")
    public Map<String, Object> resolveReport(@PathVariable Long id, @Valid @RequestBody ResolveRequest r, Authentication auth) {
        Report report = reportRepository.findById(id)
                .filter(x -> x.getTargetType() == ReportTargetType.FORUM_TOPIC || x.getTargetType() == ReportTargetType.FORUM_COMMENT)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "REPORT_NOT_FOUND", "Rapor bulunamadı."));
        AuditContext.target("REPORT", id).summary("forum sikayet karari: " + r.action() + " (" + report.getTargetType()
                + " #" + report.getTargetId() + ")");
        reportService.resolve(id, adminId(auth), r.action(), r.message(), r.reasonCode());
        return Map.of("id", id, "action", r.action().name(), "status", "RESOLVED");
    }

    /** Basic auth yoneticisinde principal Long degildir: kimlik bos kalir (denetimde "basic-admin"). */
    static Long adminId(Authentication auth) {
        return auth != null && auth.getPrincipal() instanceof Long l ? l : null;
    }

    private static int pageOf(String cursor, Integer page) {
        if (page != null) {
            return Math.max(page, 0);
        }
        if (cursor == null || cursor.isBlank()) {
            return 0;
        }
        try {
            return Math.max(0, Integer.parseInt(cursor.trim()));
        } catch (NumberFormatException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_MOD_BAD_CURSOR", "Geçersiz sayfa imleci.");
        }
    }
}
