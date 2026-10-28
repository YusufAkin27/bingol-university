package edu.bingol.backend.post.comment;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.comment.CommentDtos.CommentPage;
import edu.bingol.backend.post.comment.CommentDtos.CommentView;
import edu.bingol.backend.post.comment.CommentDtos.CreateRequest;
import edu.bingol.backend.post.comment.CommentDtos.ReplyPage;
import edu.bingol.backend.post.comment.CommentDtos.UpdateRequest;
import jakarta.validation.Valid;
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

/** Gonderi yorum uclari: yalnizca HTTP eslemesi + hiz siniri; kurallar PostCommentService'te. */
// Devre disi: sade gonderi sozlesmesi (uc RemovedFeatureController ile 410 FEATURE_REMOVED doner). Geri almak icin @RestController ekleyin ve 410 eslemesini kaldirin.
@RequestMapping("/api")
public class PostCommentController {

    private final PostCommentService service;
    private final RateLimiter limiter;

    public PostCommentController(PostCommentService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping("/posts/{id}/comments")
    public CommentPage list(@PathVariable Long id, @RequestParam(defaultValue = "new") String sort,
            @RequestParam(required = false) String cursor, @RequestParam(defaultValue = "20") int size) {
        Long uid = CurrentUser.id();
        readLimit(uid);
        return service.list(uid, id, sort, cursor, size, CurrentUser.isAdmin());
    }

    @GetMapping("/comments/{id}/replies")
    public ReplyPage replies(@PathVariable Long id, @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") int size) {
        Long uid = CurrentUser.id();
        readLimit(uid);
        return service.replies(uid, id, cursor, size, CurrentUser.isAdmin());
    }

    @PostMapping("/posts/{id}/comments")
    @ResponseStatus(HttpStatus.CREATED)
    public CommentView create(@PathVariable Long id, @Valid @RequestBody CreateRequest req) {
        Long uid = CurrentUser.id();
        writeLimit(uid);
        return service.create(uid, id, req.text(), req.parentId());
    }

    @PatchMapping("/comments/{id}")
    public CommentView update(@PathVariable Long id, @Valid @RequestBody UpdateRequest req) {
        Long uid = CurrentUser.id();
        writeLimit(uid);
        return service.update(uid, id, req.text(), CurrentUser.isAdmin());
    }

    @DeleteMapping("/comments/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        writeLimit(uid);
        service.delete(uid, id, CurrentUser.isAdmin());
    }

    private void readLimit(Long uid) {
        limiter.check("post-comment-read:" + uid, 120, Duration.ofMinutes(1));
    }

    private void writeLimit(Long uid) {
        limiter.check("post-comment-write:" + uid, 30, Duration.ofMinutes(10));
    }
}
