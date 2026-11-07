package edu.bingol.backend.forum.search;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.topic.dto.ForumPage;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import java.time.Duration;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Forum arama: {@code GET /api/forum/search}, {@code GET /api/forum/search/popular} (giris gerekli). */
@RestController
@RequestMapping("/api/forum/search")
public class ForumSearchController {

    private final ForumSearchService search;
    private final RateLimiter limiter;

    public ForumSearchController(ForumSearchService search, RateLimiter limiter) {
        this.search = search;
        this.limiter = limiter;
    }

    @GetMapping
    public ForumPage<ForumSearchItem> search(@RequestParam(required = false) String q,
                                              @RequestParam(required = false) Long categoryId,
                                              @RequestParam(required = false) String sort,
                                              @RequestParam(required = false) String cursor,
                                              @RequestParam(required = false) Integer size) {
        Long uid = CurrentUser.id();
        limiter.check("fsearch:" + uid, 60, Duration.ofMinutes(1));
        return search.search(uid, q, categoryId, sort, cursor, size);
    }

    @GetMapping("/popular")
    public List<TopicSummary> popular() {
        Long uid = CurrentUser.id();
        limiter.check("fsearchpop:" + uid, 60, Duration.ofMinutes(1));
        return search.popular(uid);
    }
}
