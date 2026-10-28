package edu.bingol.backend.post.social;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.social.MentionSuggestService.Suggestion;
import java.time.Duration;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// Devre disi: sade gonderi sozlesmesi (uc RemovedFeatureController ile 410 FEATURE_REMOVED doner). Geri almak icin @RestController ekleyin ve 410 eslemesini kaldirin.
@RequestMapping("/api/users")
public class MentionSuggestController {

    private final MentionSuggestService service;
    private final RateLimiter limiter;

    public MentionSuggestController(MentionSuggestService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping("/mention-suggest")
    public List<Suggestion> suggest(@RequestParam(defaultValue = "") String q,
                                    @RequestParam(required = false) Long postId,
                                    @RequestParam(defaultValue = "8") int size) {
        Long uid = CurrentUser.id();
        limiter.check("mention:suggest:" + uid, 60, Duration.ofMinutes(1));
        return service.suggest(uid, q, postId, size);
    }
}
