package edu.bingol.backend.post.social;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.PostDtos.FeedPage;
import java.time.Duration;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Gonderi kaydetme uclari. {@code /saved} sabit yolu {@code /{id}} desenlerinden once eslesir. */
@RestController
@RequestMapping("/api/posts")
public class PostSaveController {

    public record SaveResult(boolean saved) {}

    private final PostSaveService service;
    private final RateLimiter limiter;

    public PostSaveController(PostSaveService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @PutMapping("/{id}/save")
    public SaveResult save(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("post:save:" + uid, 120, Duration.ofMinutes(1));
        service.save(uid, id);
        return new SaveResult(true);
    }

    @DeleteMapping("/{id}/save")
    public SaveResult unsave(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("post:save:" + uid, 120, Duration.ofMinutes(1));
        service.unsave(uid, id);
        return new SaveResult(false);
    }

    @GetMapping("/saved")
    public FeedPage saved(@RequestParam(required = false) String cursor, @RequestParam(defaultValue = "10") int size) {
        Long uid = CurrentUser.id();
        limiter.check("post:read:" + uid, 120, Duration.ofMinutes(1));
        return service.list(uid, cursor, size);
    }
}
