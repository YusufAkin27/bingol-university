package edu.bingol.backend.post.admin;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.admin.AdminPostService.CommentPage;
import edu.bingol.backend.post.admin.AdminPostService.CommentRow;
import edu.bingol.backend.post.admin.AdminPostService.PostDetail;
import edu.bingol.backend.post.admin.AdminPostService.PostPage;
import edu.bingol.backend.post.admin.AdminPostService.PostRow;
import edu.bingol.backend.post.admin.AdminPostService.Stats;
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
 * Yonetici gonderi/yorum moderasyonu (`/api/admin/**` yalnizca ADMIN). Yazma islemleri AuditInterceptor ile
 * denetlenir; medya akisi (`GET /api/admin/posts/media/{id}`) PostMediaController'dadir (denetlenir).
 */
@RestController
@RequestMapping("/api/admin")
public class AdminPostController {

    static final int PER_MINUTE = 120;

    public record ReasonRequest(@Size(max = 300) String reason) {}

    private final AdminPostService service;
    private final RateLimiter limiter;

    public AdminPostController(AdminPostService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /** Imlec = gonderi id (en yeni once); q = yazar adi/e-postasi; tarih = YYYY-AA-GG (Europe/Istanbul). */
    @GetMapping("/posts")
    public PostPage list(@RequestParam(required = false) Long cursor, @RequestParam(defaultValue = "20") int size,
                         @RequestParam(required = false) String q, @RequestParam(required = false) Boolean hidden,
                         @RequestParam(required = false) Boolean deleted,
                         @RequestParam(required = false) Boolean hasMedia, @RequestParam(required = false) String from,
                         @RequestParam(required = false) String to) {
        limit();
        return service.list(cursor, size, q, hidden, deleted, hasMedia, from, to);
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

    @DeleteMapping("/posts/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable long id) {
        limit();
        service.delete(CurrentUser.id(), id);
    }

    @GetMapping("/posts/{id}/comments")
    public CommentPage comments(@PathVariable long id, @RequestParam(required = false) Long cursor,
                                @RequestParam(defaultValue = "30") int size) {
        limit();
        return service.comments(id, cursor, size);
    }

    @PostMapping("/comments/{id}/hide")
    public CommentRow hideComment(@PathVariable long id, @RequestBody(required = false) ReasonRequest body) {
        limit();
        return service.hideComment(id);
    }

    @PostMapping("/comments/{id}/unhide")
    public CommentRow unhideComment(@PathVariable long id, @RequestBody(required = false) ReasonRequest body) {
        limit();
        return service.unhideComment(id);
    }

    @DeleteMapping("/comments/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteComment(@PathVariable long id) {
        limit();
        service.deleteComment(CurrentUser.id(), id);
    }

    private void limit() {
        limiter.check("adminposts:" + CurrentUser.id(), PER_MINUTE, Duration.ofMinutes(1));
    }
}
