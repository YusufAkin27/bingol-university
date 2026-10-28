package edu.bingol.backend.community.admin;

import edu.bingol.backend.admin.AdminReasonRequired;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.admin.ClubAdminDtos.PageResult;
import edu.bingol.backend.community.admin.ClubAdminDtos.PostActionResult;
import edu.bingol.backend.community.admin.ClubAdminDtos.PostDetail;
import edu.bingol.backend.community.admin.ClubAdminDtos.PostEditRequest;
import edu.bingol.backend.community.admin.ClubAdminDtos.PostRow;
import edu.bingol.backend.community.admin.ClubAdminDtos.ReasonRequest;
import edu.bingol.backend.community.admin.ClubContentAdminService.ContentFilter;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici kulup gonderisi + duyurusu moderasyonu (P10; `/api/admin/**` yalniz ADMIN). Kesfet akisi gonderileri
 * (`/api/admin/posts`) ayri modulde; bunlar KULUP akisi icindir. Hedef denetim: COMMUNITY_POST/{id}.
 */
@RestController
@RequestMapping("/api/admin/community-posts")
public class ClubContentAdminController {

    static final int READ_PER_MINUTE = 120;

    private final ClubContentAdminService service;
    private final RateLimiter limiter;

    public ClubContentAdminController(ClubContentAdminService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /** kind: POST|ANNOUNCEMENT|ALL; status: VISIBLE|HIDDEN|DELETED|ALL; sort: createdAt|reports; from/to: YYYY-AA-GG. */
    @GetMapping
    public PageResult<PostRow> list(@RequestParam(required = false) Long communityId,
                                    @RequestParam(required = false) String kind,
                                    @RequestParam(required = false) String status,
                                    @RequestParam(required = false) Integer minReports,
                                    @RequestParam(required = false) String q,
                                    @RequestParam(required = false) Long authorId,
                                    @RequestParam(required = false) String from,
                                    @RequestParam(required = false) String to,
                                    @RequestParam(required = false) String sort,
                                    @RequestParam(defaultValue = "0") int page,
                                    @RequestParam(defaultValue = "20") int size) {
        limit();
        return service.list(new ContentFilter(communityId, kind, status, minReports, q, authorId, from, to, sort), page, size);
    }

    @GetMapping("/{id}")
    public PostDetail detail(@PathVariable Long id) {
        limit();
        return service.detail(id);
    }

    @PatchMapping("/{id}")
    public PostRow edit(@PathVariable Long id, @Valid @RequestBody PostEditRequest body) {
        return service.edit(id, body.text(), body.reason());
    }

    @PostMapping("/{id}/hide")
    public PostRow hide(@PathVariable Long id, @RequestBody(required = false) ReasonRequest body) {
        return service.hide(id, reason(body));
    }

    @PostMapping("/{id}/unhide")
    public PostRow unhide(@PathVariable Long id, @RequestBody(required = false) ReasonRequest body) {
        return service.unhide(id);
    }

    /** Silme GERI ALINAMAZ (gorsel dosyasi silinir); sebep zorunlu. */
    @AdminReasonRequired
    @DeleteMapping("/{id}")
    public PostActionResult delete(@PathVariable Long id, @RequestBody(required = false) ReasonRequest body) {
        return service.delete(id, reason(body));
    }

    private static String reason(ReasonRequest body) {
        String h = AuditContext.currentReason();
        return h != null ? h : body == null ? null : body.reason();
    }

    private void limit() {
        Long id = ClubAdminService.actorId();
        limiter.check("adminclubposts:" + (id == null ? "basic" : id), READ_PER_MINUTE, Duration.ofMinutes(1));
    }
}
