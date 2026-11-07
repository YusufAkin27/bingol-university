package edu.bingol.backend.forum.comment;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.comment.ForumCommentDtos.CommentPage;
import edu.bingol.backend.forum.comment.ForumCommentDtos.CommentView;
import edu.bingol.backend.forum.comment.ForumCommentDtos.CreateCommentRequest;
import edu.bingol.backend.forum.comment.ForumCommentDtos.EditCommentRequest;
import edu.bingol.backend.forum.comment.ForumCommentDtos.LikeState;
import edu.bingol.backend.forum.comment.ForumCommentDtos.SaveState;
import java.time.Duration;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Forum yorum uclari: yalniz HTTP eslemesi + hiz siniri; kurallar ForumCommentService'te. */
@RestController
@RequestMapping("/api/forum")
public class ForumCommentController {

    private final ForumCommentService service;
    private final RateLimiter limiter;

    public ForumCommentController(ForumCommentService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /** sort=BEST|NEWEST|OLDEST (varsayilan BEST), imlec opak, size varsayilan 15 (en cok 30). */
    @GetMapping("/topics/{id}/comments")
    public CommentPage list(@PathVariable Long id, @RequestParam(required = false) String sort,
                            @RequestParam(required = false) String cursor, @RequestParam(required = false) Integer size) {
        Long uid = CurrentUser.id();
        read(uid);
        return service.list(uid, id, parseSort(sort), cursor, size);
    }

    @PostMapping("/topics/{id}/comments")
    @ResponseStatus(HttpStatus.CREATED)
    public CommentView create(@PathVariable Long id, @RequestBody CreateCommentRequest req,
                              @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey) {
        Long uid = CurrentUser.id();
        limiter.check("forum:comment:create:" + uid, 20, Duration.ofMinutes(1));
        return service.create(uid, id, req, idempotencyKey);
    }

    @GetMapping("/comments/{id}")
    public CommentView get(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        read(uid);
        return service.get(uid, id);
    }

    @GetMapping("/comments/{id}/replies")
    public CommentPage replies(@PathVariable Long id, @RequestParam(required = false) String cursor,
                               @RequestParam(required = false) Integer size) {
        Long uid = CurrentUser.id();
        read(uid);
        return service.replies(uid, id, cursor, size);
    }

    @PatchMapping("/comments/{id}")
    public CommentView edit(@PathVariable Long id, @RequestBody EditCommentRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("forum:comment:write:" + uid, 60, Duration.ofMinutes(1));
        return service.edit(uid, id, req.body());
    }

    @DeleteMapping("/comments/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:comment:write:" + uid, 60, Duration.ofMinutes(1));
        service.delete(uid, id);
    }

    @PutMapping("/comments/{id}/like")
    public LikeState like(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:comment:like:" + uid, 120, Duration.ofMinutes(1));
        return service.like(uid, id);
    }

    @DeleteMapping("/comments/{id}/like")
    public LikeState unlike(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:comment:like:" + uid, 120, Duration.ofMinutes(1));
        return service.unlike(uid, id);
    }

    @PutMapping("/comments/{id}/bookmark")
    public SaveState save(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:comment:save:" + uid, 120, Duration.ofMinutes(1));
        return service.save(uid, id);
    }

    @DeleteMapping("/comments/{id}/bookmark")
    public SaveState unsave(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:comment:save:" + uid, 120, Duration.ofMinutes(1));
        return service.unsave(uid, id);
    }

    private void read(Long uid) {
        limiter.check("forum:comment:read:" + uid, 240, Duration.ofMinutes(1));
    }

    private static ForumCommentService.Sort parseSort(String sort) {
        if (sort == null || sort.isBlank()) {
            return ForumCommentService.Sort.BEST;
        }
        try {
            return ForumCommentService.Sort.valueOf(sort.strip().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz sıralama.");
        }
    }
}
