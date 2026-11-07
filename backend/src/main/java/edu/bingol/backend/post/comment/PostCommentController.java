package edu.bingol.backend.post.comment;

import edu.bingol.backend.admin.rbac.PermissionMatrix;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.SystemAdminAudit;
import edu.bingol.backend.post.comment.CommentDtos.CommentPage;
import edu.bingol.backend.post.comment.CommentDtos.CommentView;
import edu.bingol.backend.post.comment.CommentDtos.CreateCommentRequest;
import edu.bingol.backend.post.comment.CommentDtos.LikeState;
import jakarta.validation.Valid;
import java.time.Duration;
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

/** Gonderi/reel yorum uclari: yalniz HTTP eslemesi + hiz siniri; kurallar PostCommentService'te. */
@RestController
@RequestMapping("/api")
public class PostCommentController {

    private final PostCommentService service;
    private final RateLimiter limiter;

    public PostCommentController(PostCommentService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /** Sistem yoneticisi mudahalesi denetimi (istege bagli; PostController ile ayni desen). */
    private SystemAdminAudit adminAudit;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setAdminAudit(SystemAdminAudit adminAudit) {
        this.adminAudit = adminAudit;
    }

    /** sort=top|new (varsayilan top), cursor opak, size varsayilan 20 (en cok 50). */
    @GetMapping("/posts/{id}/comments")
    public CommentPage list(@PathVariable Long id, @RequestParam(required = false) String sort,
                            @RequestParam(required = false) String cursor, @RequestParam(defaultValue = "20") int size) {
        Long uid = CurrentUser.id();
        read(uid);
        return service.list(uid, id, sort, cursor, size);
    }

    @PostMapping("/posts/{id}/comments")
    @ResponseStatus(HttpStatus.CREATED)
    public CommentView create(@PathVariable Long id, @Valid @RequestBody CreateCommentRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("comment:create:" + uid, 20, Duration.ofMinutes(1));
        limiter.check("comment:create-hour:" + uid, 200, Duration.ofHours(1));
        return service.create(uid, id, req);
    }

    @GetMapping({"/post-comments/{cid}", "/comments/{cid}"})
    public CommentView get(@PathVariable Long cid) {
        Long uid = CurrentUser.id();
        read(uid);
        return service.get(uid, cid);
    }

    @GetMapping({"/post-comments/{cid}/replies", "/comments/{cid}/replies"})
    public CommentPage replies(@PathVariable Long cid, @RequestParam(required = false) String cursor,
                               @RequestParam(defaultValue = "10") int size) {
        Long uid = CurrentUser.id();
        read(uid);
        return service.replies(uid, cid, cursor, size);
    }

    @DeleteMapping({"/post-comments/{cid}", "/comments/{cid}"})
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long cid) {
        Long uid = CurrentUser.id();
        limiter.check("comment:write:" + uid, 60, Duration.ofMinutes(1));
        // CONTENT_HIDE izinli yonetici baskasinin yorumunu silebilir ve bu mudahale admin_audit'e yazilir
        boolean override = CurrentUser.hasAdminPermission(PermissionMatrix.CONTENT_HIDE);
        service.delete(uid, cid, override);
        if (override) {
            SystemAdminAudit.used(adminAudit, Actor.current(), "POST_COMMENT", cid, "yorum silme");
        }
    }

    @PutMapping("/post-comments/{cid}/like")
    public LikeState like(@PathVariable Long cid) {
        Long uid = CurrentUser.id();
        limiter.check("comment:like:" + uid, 120, Duration.ofMinutes(1));
        return service.like(uid, cid);
    }

    @DeleteMapping("/post-comments/{cid}/like")
    public LikeState unlike(@PathVariable Long cid) {
        Long uid = CurrentUser.id();
        limiter.check("comment:like:" + uid, 120, Duration.ofMinutes(1));
        return service.unlike(uid, cid);
    }

    /** Sozlesme yolu: 204, idempotent (eski /post-comments/{cid}/like LikeState govdesi doner). */
    @PutMapping("/comments/{cid}/like")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void likeNoContent(@PathVariable Long cid) {
        Long uid = CurrentUser.id();
        limiter.check("comment:like:" + uid, 120, Duration.ofMinutes(1)); // eski uc ile ayni sayac
        service.like(uid, cid);
    }

    @DeleteMapping("/comments/{cid}/like")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unlikeNoContent(@PathVariable Long cid) {
        Long uid = CurrentUser.id();
        limiter.check("comment:like:" + uid, 120, Duration.ofMinutes(1));
        service.unlike(uid, cid);
    }

    private void read(Long uid) {
        limiter.check("comment:read:" + uid, 240, Duration.ofMinutes(1));
    }
}
