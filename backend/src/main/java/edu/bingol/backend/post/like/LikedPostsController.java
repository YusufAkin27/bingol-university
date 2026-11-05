package edu.bingol.backend.post.like;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.PostDtos.FeedPage;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** GET /api/posts/liked?kind=ALL|PHOTO|VIDEO&cursor=&size= : benim begendigim gonderiler / Reels (yalniz kendi listem). */
@RestController
@RequestMapping("/api/posts")
public class LikedPostsController {

    private final LikedPostsService service;
    private final RateLimiter limiter;

    public LikedPostsController(LikedPostsService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /** Sabit yol "liked", /posts/{id} eslemesinden onceliklidir. */
    @GetMapping("/liked")
    public FeedPage liked(@RequestParam(defaultValue = "ALL") String kind, @RequestParam(required = false) String cursor,
                          @RequestParam(defaultValue = "12") int size) {
        Long uid = CurrentUser.id();
        limiter.check("post:read:" + uid, 120, Duration.ofMinutes(1));
        return service.liked(uid, kind, cursor, size);
    }
}
