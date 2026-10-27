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

    /**
     * GET /api/search?q=&type=NEWS|ANNOUNCEMENT|EVENT_OFFICIAL|COMMUNITY|EVENT|POSTS&limit=5&cursor= (giris gerekli).
     * type yoksa tur basina gruplu ozet (limit en fazla 20); type varsa sayfali liste (limit en fazla 50,
     * devam icin nextCursor'u cursor olarak gonderin).
     */
    @GetMapping("/search")
    public SearchResult search(@RequestParam String q,
                               @RequestParam(required = false) SearchType type,
                               @RequestParam(required = false) Integer limit,
                               @RequestParam(required = false) Long cursor) {
        limiter.check("search:user:" + CurrentUser.id(), 60, Duration.ofMinutes(1));
        return type == null ? search.search(q, null, limit) : search.searchPage(q, type, limit, cursor);
    }
}
