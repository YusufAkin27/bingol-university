package edu.bingol.backend.search;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.search.SearchService.SearchResult;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class SearchController {

    private final SearchService search;
    private final RateLimiter limiter;

    public SearchController(SearchService search, RateLimiter limiter) {
        this.search = search;
        this.limiter = limiter;
    }

    /** GET /api/search?q=&type=NEWS|ANNOUNCEMENT|EVENT_OFFICIAL|COMMUNITY|EVENT&limit=5 (giris gerekli) */
    @GetMapping("/search")
    public SearchResult search(@RequestParam String q,
                               @RequestParam(required = false) SearchType type,
                               @RequestParam(required = false) Integer limit) {
        limiter.check("search:user:" + CurrentUser.id(), 60, Duration.ofMinutes(1));
        return search.search(q, type, limit);
    }
}
