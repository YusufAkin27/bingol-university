package edu.bingol.backend.post.admin;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.admin.AdminPostService.PostDetail;
import edu.bingol.backend.post.admin.AdminPostService.PostPage;
import edu.bingol.backend.post.admin.AdminPostService.PostRow;
import edu.bingol.backend.post.admin.AdminPostService.Stats;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import java.time.Duration;
import org.springframework.http.HttpStatus;
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
 * Yonetici gonderi moderasyonu (`/api/admin/**` yalnizca ADMIN). Yazma islemleri AuditInterceptor ile
 * denetlenir; medya akisi (`GET /api/admin/posts/media/{id}`) PostMediaController'dadir (denetlenir).
 */
@RestController
@RequestMapping("/api/admin")
public class AdminPostController {

    static final int PER_MINUTE = 120;

    public record ReasonRequest(@Size(max = 300) String reason) {}

    /** Metin bos/bosluk ise temizlenir (fotograf kalir); bicim kurali serviste. */
    public record EditRequest(@Size(max = 1000) String text) {}

    private final AdminPostService service;
    private final RateLimiter limiter;

    public AdminPostController(AdminPostService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /**
     * Imlec = gonderi id (en yeni once). q = gonderi metni / yazar adi / e-postasi; status = ALL|VISIBLE|HIDDEN|DELETED;
     * authorId; minReports = en az N acik sikayet; from/to = YYYY-AA-GG (Europe/Istanbul).
     */
    @GetMapping("/posts")
    public PostPage list(@RequestParam(required = false) Long cursor, @RequestParam(defaultValue = "20") int size,
                         @RequestParam(required = false) String q, @RequestParam(required = false) Boolean hidden,
                         @RequestParam(required = false) Boolean deleted,
                         @RequestParam(required = false) Boolean hasMedia, @RequestParam(required = false) String from,
                         @RequestParam(required = false) String to, @RequestParam(required = false) String status,
                         @RequestParam(required = false) Long authorId,
                         @RequestParam(required = false) Integer minReports) {
        limit();
        return service.list(cursor, size, q, hidden, deleted, hasMedia, from, to, status, authorId, minReports);
    }

    @GetMapping("/posts/stats")
    public Stats stats() {
        limit();
        return service.stats();
    }

    @GetMapping("/posts/{id}")
    public PostDetail detail(@PathVariable long id) {
        limit();
        return service.detail(id);
    }

    @PostMapping("/posts/{id}/hide")
    public PostRow hide(@PathVariable long id, @RequestBody(required = false) ReasonRequest body) {
        limit();
        return service.hide(id, body == null ? null : body.reason());
    }

    @PostMapping("/posts/{id}/unhide")
    public PostRow unhide(@PathVariable long id, @RequestBody(required = false) ReasonRequest body) {
        limit();
        return service.unhide(id);
    }

    /** Metin duzenleme (denetim kaydi; yazara bildirim). */
    @PatchMapping("/posts/{id}")
    public PostRow edit(@PathVariable long id, @Valid @RequestBody EditRequest body) {
        limit();
        return service.editText(id, body.text());
    }

    /** Silme; istege bagli govde {reason} yazara giden gerekcedir. Acik sikayetler sonuclandirilir. */
    @DeleteMapping("/posts/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable long id, @RequestBody(required = false) ReasonRequest body) {
        limit();
        service.delete(CurrentUser.id(), id, body == null ? null : body.reason());
    }

    private void limit() {
        limiter.check("adminposts:" + CurrentUser.id(), PER_MINUTE, Duration.ofMinutes(1));
    }
}
