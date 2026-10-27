package edu.bingol.backend.post.social;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.social.HashtagService.TagCount;
import java.time.Duration;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/hashtags")
public class HashtagController {

    private final HashtagService service;
    private final RateLimiter limiter;

    public HashtagController(HashtagService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping("/trending")
    public List<TagCount> trending(@RequestParam(defaultValue = "10") int size) {
        limit();
        return service.trending(size);
    }

    @GetMapping("/suggest")
    public List<TagCount> suggest(@RequestParam(defaultValue = "") String q) {
        limit();
        return service.suggest(q);
    }

    @GetMapping("/{tag}/posts")
    public FeedPage posts(@PathVariable String tag, @RequestParam(required = false) String cursor,
                          @RequestParam(defaultValue = "10") int size) {
        Long uid = limit();
        return service.posts(uid, tag, cursor, size);
    }

    private Long limit() {
        Long uid = CurrentUser.id();
        limiter.check("hashtag:" + uid, 60, Duration.ofMinutes(1));
        return uid;
    }
}
