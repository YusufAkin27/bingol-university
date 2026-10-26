package edu.bingol.backend.profile;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.profile.dto.ProfileDtos.MeSummary;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/me")
public class MeSummaryController {

    private final MeSummaryService summary;
    private final RateLimiter limiter;

    public MeSummaryController(MeSummaryService summary, RateLimiter limiter) {
        this.summary = summary;
        this.limiter = limiter;
    }

    /** GET /api/me/summary: {communities, events, bookmarks, unreadNotifications, unreadMessages} (giris gerekli). */
    @GetMapping("/summary")
    public MeSummary get() {
        Long uid = CurrentUser.id();
        limiter.check("me-summary:user:" + uid, 120, Duration.ofMinutes(1));
        return summary.summary(uid);
    }
}
