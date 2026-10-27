package edu.bingol.backend.post.follow;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.follow.FollowService.FollowResult;
import edu.bingol.backend.post.follow.FollowService.Suggestion;
import edu.bingol.backend.post.follow.FollowService.UserPage;
import java.time.Duration;
import java.util.List;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
public class FollowController {

    private final FollowService service;
    private final RateLimiter limiter;

    public FollowController(FollowService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @PostMapping("/{id}/follow")
    public FollowResult follow(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("follow:" + uid, 60, Duration.ofMinutes(1));
        return service.follow(uid, id);
    }

    @DeleteMapping("/{id}/follow")
    public FollowResult unfollow(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("follow:" + uid, 60, Duration.ofMinutes(1));
        return service.unfollow(uid, id);
    }

    @GetMapping("/{id}/followers")
    public UserPage followers(@PathVariable Long id, @RequestParam(required = false) String cursor,
                              @RequestParam(defaultValue = "20") int size) {
        Long uid = read();
        return service.followers(uid, id, cursor, size);
    }

    @GetMapping("/{id}/following")
    public UserPage following(@PathVariable Long id, @RequestParam(required = false) String cursor,
                              @RequestParam(defaultValue = "20") int size) {
        Long uid = read();
        return service.following(uid, id, cursor, size);
    }

    @GetMapping("/me/follow-suggestions")
    public List<Suggestion> suggestions(@RequestParam(defaultValue = "10") int size) {
        Long uid = read();
        return service.suggestions(uid, size);
    }

    private Long read() {
        Long uid = CurrentUser.id();
        limiter.check("follow:read:" + uid, 120, Duration.ofMinutes(1));
        return uid;
    }
}
