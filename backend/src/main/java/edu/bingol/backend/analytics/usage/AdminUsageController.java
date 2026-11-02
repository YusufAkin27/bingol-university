package edu.bingol.backend.analytics.usage;

import edu.bingol.backend.analytics.usage.UsageDtos.Features;
import edu.bingol.backend.analytics.usage.UsageDtos.Flow;
import edu.bingol.backend.analytics.usage.UsageDtos.Hourly;
import edu.bingol.backend.analytics.usage.UsageDtos.Segments;
import edu.bingol.backend.analytics.usage.UsageDtos.Summary;
import edu.bingol.backend.analytics.usage.UsageDtos.TopActions;
import edu.bingol.backend.analytics.usage.UsageDtos.TopScreens;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.dbmaint.UsageRollup;
import java.time.Duration;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Kullanim istatistikleri (/api/admin/analytics/usage/*). Yalnizca toplulastirilmis, kimliksiz veri doner.
 * Izin: `analytics.read` (AdminPermissionPolicy `/api/admin/analytics(/.*)?` kurali kapsar).
 */
@RestController
@RequestMapping("/api/admin/analytics/usage")
public class AdminUsageController {

    private final UsageReportService reports;
    private final UsageRollup rollup;
    private final RateLimiter limiter;

    public AdminUsageController(UsageReportService reports, UsageRollup rollup, RateLimiter limiter) {
        this.reports = reports;
        this.rollup = rollup;
        this.limiter = limiter;
    }

    /** Bugunun kismi ozetini hemen yeniden hesaplar (15 dk beklemeden). Dakikada en cok 2 kez. */
    @PostMapping("/refresh")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public Map<String, String> refresh() {
        limiter.check("usage:refresh", 2, Duration.ofMinutes(1));
        String day = rollup.refreshTodayNow().toString();
        reports.invalidateCache();
        return Map.of("refreshedDay", day);
    }

    @GetMapping("/summary")
    public Summary summary(@RequestParam(required = false) String from, @RequestParam(required = false) String to) {
        return reports.summary(from, to);
    }

    @GetMapping("/top-screens")
    public TopScreens topScreens(@RequestParam(required = false) String from,
                                 @RequestParam(required = false) String to) {
        return reports.topScreens(from, to);
    }

    @GetMapping("/top-actions")
    public TopActions topActions(@RequestParam(required = false) String from,
                                 @RequestParam(required = false) String to) {
        return reports.topActions(from, to);
    }

    @GetMapping("/flow")
    public Flow flow(@RequestParam(required = false) String from, @RequestParam(required = false) String to) {
        return reports.flow(from, to);
    }

    @GetMapping("/hourly")
    public Hourly hourly(@RequestParam(required = false) String from, @RequestParam(required = false) String to) {
        return reports.hourly(from, to);
    }

    @GetMapping("/segments")
    public Segments segments(@RequestParam(required = false) String from, @RequestParam(required = false) String to) {
        return reports.segments(from, to);
    }

    @GetMapping("/features")
    public Features features(@RequestParam(required = false) String from, @RequestParam(required = false) String to) {
        return reports.features(from, to);
    }
}
