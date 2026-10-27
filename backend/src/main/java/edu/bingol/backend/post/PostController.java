package edu.bingol.backend.post;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.PostDtos.CreatePostRequest;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.PostDtos.UpdatePostRequest;
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

/** Gönderi uçları: yalnız HTTP eşlemesi + hız sınırı; kurallar PostService'te. */
@RestController
@RequestMapping("/api")
public class PostController {

    private final PostService service;
    private final RateLimiter limiter;

    public PostController(PostService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @PostMapping("/posts")
    @ResponseStatus(HttpStatus.CREATED)
    public PostView create(@Valid @RequestBody CreatePostRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("post:create:" + uid, 20, Duration.ofHours(1));
        return service.create(uid, req);
    }

    /** Sabit yol "mine", {id} eşlemesinden önceliklidir. */
    @GetMapping("/posts/mine")
    public FeedPage mine(@RequestParam(required = false) String cursor, @RequestParam(defaultValue = "10") int size) {
        Long uid = CurrentUser.id();
        read(uid);
        return service.byAuthor(uid, uid, cursor, size);
    }

    @GetMapping("/posts/{id}")
    public PostView get(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        read(uid);
        return service.get(uid, id);
    }

    @PatchMapping("/posts/{id}")
    public PostView update(@PathVariable Long id, @Valid @RequestBody UpdatePostRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("post:write:" + uid, 30, Duration.ofMinutes(1));
        return service.update(uid, id, req.text());
    }

    @DeleteMapping("/posts/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("post:write:" + uid, 30, Duration.ofMinutes(1));
        service.delete(uid, id, CurrentUser.isAdmin());
    }

    @GetMapping("/users/{id}/posts")
    public FeedPage byUser(@PathVariable Long id, @RequestParam(required = false) String cursor,
                           @RequestParam(defaultValue = "10") int size) {
        Long uid = CurrentUser.id();
        read(uid);
        return service.byAuthor(uid, id, cursor, size);
    }

    private void read(Long uid) {
        limiter.check("post:read:" + uid, 120, Duration.ofMinutes(1));
    }
}
