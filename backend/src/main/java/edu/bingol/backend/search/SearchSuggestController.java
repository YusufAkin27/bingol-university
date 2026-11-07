package edu.bingol.backend.search;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.search.SearchSuggestService.SuggestResult;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SearchSuggestController {

    private final SearchSuggestService suggest;
    private final RateLimiter limiter;

    public SearchSuggestController(SearchSuggestService suggest, RateLimiter limiter) {
        this.suggest = suggest;
        this.limiter = limiter;
    }

    /** GET /api/search/suggest?q= (giris gerekli, q en az 2 karakter): en fazla 8 onek onerisi; arama gecmisi tutulmaz. */
    @GetMapping("/api/search/suggest")
    public SuggestResult suggest(@RequestParam String q) {
        Long uid = CurrentUser.id();
        limiter.check("search-suggest:user:" + uid, 120, Duration.ofMinutes(1));
        return suggest.suggest(uid, q);
    }
}
