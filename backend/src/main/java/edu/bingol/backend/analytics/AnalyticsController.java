package edu.bingol.backend.analytics;

import edu.bingol.backend.analytics.AnalyticsDtos.EventsRequest;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Mobil uygulamanin kullanim olaylarini gonderdigi uc (giris gerekli, dakikada 30 istek). */
@RestController
@RequestMapping("/api/analytics")
public class AnalyticsController {

    private final AnalyticsService analytics;
    private final RateLimiter limiter;

    public AnalyticsController(AnalyticsService analytics, RateLimiter limiter) {
        this.analytics = analytics;
        this.limiter = limiter;
    }

    @PostMapping("/events")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void events(@Valid @RequestBody EventsRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("analytics:user:" + uid, 30, Duration.ofMinutes(1));
        analytics.record(uid, r.events());
    }
}
