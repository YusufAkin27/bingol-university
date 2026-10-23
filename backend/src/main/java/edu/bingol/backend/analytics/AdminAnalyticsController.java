package edu.bingol.backend.analytics;

import edu.bingol.backend.analytics.ReportDtos.ActiveUsersReport;
import edu.bingol.backend.analytics.ReportDtos.Breakdown;
import edu.bingol.backend.analytics.ReportDtos.ContentReport;
import edu.bingol.backend.analytics.ReportDtos.Engagement;
import edu.bingol.backend.analytics.ReportDtos.Overview;
import edu.bingol.backend.analytics.ReportDtos.PushReport;
import edu.bingol.backend.analytics.ReportDtos.Registrations;
import edu.bingol.backend.analytics.ReportDtos.Retention;
import edu.bingol.backend.analytics.ReportDtos.SupportReport;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Yonetim paneli analitik uclari (/api/admin/** => ROLE_ADMIN). Yalnizca toplulastirilmis veri doner. */
@RestController
@RequestMapping("/api/admin/analytics")
public class AdminAnalyticsController {

    private final AnalyticsReportService reports;

    public AdminAnalyticsController(AnalyticsReportService reports) {
        this.reports = reports;
    }

    @GetMapping("/overview")
    public Overview overview() {
        return reports.overview();
    }

    @GetMapping("/registrations")
    public Registrations registrations(@RequestParam(required = false) String from,
                                       @RequestParam(required = false) String to) {
        return reports.registrations(from, to);
    }

    @GetMapping("/active-users")
    public ActiveUsersReport activeUsers(@RequestParam(required = false) String from,
                                         @RequestParam(required = false) String to) {
        return reports.activeUsers(from, to);
    }

    @GetMapping("/breakdown")
    public Breakdown breakdown(@RequestParam String dimension) {
        return reports.breakdown(dimension);
    }

    @GetMapping("/engagement")
    public Engagement engagement(@RequestParam(required = false) String from,
                                 @RequestParam(required = false) String to) {
        return reports.engagement(from, to);
    }

    @GetMapping("/retention")
    public Retention retention() {
        return reports.retention();
    }

    @GetMapping("/support")
    public SupportReport support() {
        return reports.support();
    }

    @GetMapping("/push")
    public PushReport push() {
        return reports.push();
    }

    @GetMapping("/content")
    public ContentReport content(@RequestParam(required = false) String from,
                                 @RequestParam(required = false) String to) {
        return reports.content(from, to);
    }
}
