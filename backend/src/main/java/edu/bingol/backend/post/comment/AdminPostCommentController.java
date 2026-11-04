package edu.bingol.backend.post.comment;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.comment.AdminPostCommentService.Page;
import edu.bingol.backend.post.comment.AdminPostCommentService.Row;
import jakarta.validation.constraints.Size;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici yorum moderasyonu (`/api/admin/**` yalnizca ADMIN; izinler AdminPermissionPolicy: okuma content.read,
 * gizle/sil content.hide). Yazma islemleri AuditInterceptor ile denetlenir.
 */
@RestController
@RequestMapping("/api/admin")
public class AdminPostCommentController {

    static final int PER_MINUTE = 120;

    public record ReasonRequest(@Size(max = 300) String reason) {}

    private final AdminPostCommentService service;
    private final RateLimiter limiter;

    public AdminPostCommentController(AdminPostCommentService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /** Imlec = yorum id (en yeni once); status = ALL|VISIBLE|HIDDEN|DELETED. */
    @GetMapping("/posts/{id}/comments")
    public Page list(@PathVariable long id, @RequestParam(required = false) Long cursor,
                     @RequestParam(defaultValue = "20") int size, @RequestParam(required = false) String status) {
        limit();
        return service.list(id, cursor, size, status);
    }

    @PostMapping("/post-comments/{id}/hide")
    public Row hide(@PathVariable long id, @RequestBody(required = false) ReasonRequest body) {
        limit();
        return service.hide(id, body == null ? null : body.reason());
    }

    @PostMapping("/post-comments/{id}/unhide")
    public Row unhide(@PathVariable long id) {
        limit();
        return service.unhide(id);
    }

    /** Silme; istege bagli govde {reason} yazara giden gerekcedir. Acik sikayetler sonuclandirilir. */
    @DeleteMapping("/post-comments/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable long id, @RequestBody(required = false) ReasonRequest body) {
        limit();
        service.delete(CurrentUser.id(), id, body == null ? null : body.reason());
    }

    private void limit() {
        limiter.check("adminposts:" + CurrentUser.id(), PER_MINUTE, Duration.ofMinutes(1));
    }
}
