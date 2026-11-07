package edu.bingol.backend.post.reel;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.PostDtos.FeedPage;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** GET /api/users/{id}/reels: yalniz HTTP eslemesi + hiz siniri (kurallar UserReelsService'te). */
@RestController
@RequestMapping("/api")
public class UserReelsController {

    private final UserReelsService service;
    private final RateLimiter limiter;

    public UserReelsController(UserReelsService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping("/users/{id}/reels")
    public FeedPage reels(@PathVariable Long id, @RequestParam(required = false) String cursor,
                          @RequestParam(defaultValue = "12") int size) {
        Long uid = CurrentUser.id();
        limiter.check("post:read:" + uid, 120, Duration.ofMinutes(1));
        return service.byAuthor(uid, id, cursor, size);
    }
}
