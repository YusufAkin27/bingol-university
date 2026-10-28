package edu.bingol.backend.post;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.PostDtos.FeedPage;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Keşfet akışı: top (puanlı) | latest | popular (+ following | department). size: 0 = kapsam varsayılanı. */
@RestController
@RequestMapping("/api/feed")
public class FeedController {

    private final PostService service;
    private final RateLimiter limiter;

    public FeedController(PostService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping
    public FeedPage feed(@RequestParam(defaultValue = "latest") String scope,
                         @RequestParam(required = false) String cursor, @RequestParam(defaultValue = "0") int size) {
        Long uid = CurrentUser.id();
        limiter.check("post:read:" + uid, 120, Duration.ofMinutes(1));
        return service.feed(uid, scope, cursor, size);
    }
}
