package edu.bingol.backend.moderation;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.moderation.dto.ModerationDtos.CreateReportRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/reports")
public class ReportController {

    private final ReportService reports;
    private final RateLimiter limiter;

    public ReportController(ReportService reports, RateLimiter limiter) {
        this.reports = reports;
        this.limiter = limiter;
    }

    /** Herhangi bir icerigi/kullaniciyi raporla. Kullanici basina gunde 20 rapor. */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Long> create(@Valid @RequestBody CreateReportRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("report:user:" + uid, 20, Duration.ofDays(1));
        // Ani yogun gonderim (spam/otomasyon) icin kisa pencere
        limiter.check("report:burst:" + uid, 5, Duration.ofMinutes(1));
        return Map.of("id", reports.create(uid, r).getId());
    }
}
