package edu.bingol.backend.moderation;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.moderation.dto.ModerationDtos.CreateReportRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
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

    /**
     * "Sikayetlerim": kullanicinin kendi gonderdigi raporlarin GENEL durumu (OPEN = inceleniyor, RESOLVED =
     * sonuclandi). Hedef kimligi, karar/sonuc, moderator notu, diger raporlayicilar ve hedef kullanicinin verisi
     * ASLA donmez (rapor sonucu yalniz "sonuclandi" olarak bildirilir; ceza bilgisi sizdirilmaz).
     */
    @GetMapping("/mine")
    public CursorPage<MyReportView> mine(@RequestParam(required = false) Long cursor,
                                         @RequestParam(defaultValue = "20") int limit) {
        Long uid = CurrentUser.id();
        limiter.check("report:mine:" + uid, 60, Duration.ofMinutes(1));
        int size = CursorPage.clampSize(limit);
        return CursorPage.of(reports.mine(uid, cursor, size + 1), size, Report::getId, MyReportView::of);
    }

    /** Raportorun kendi raporunun guvenli gorunumu (hedef kimligi ve karar ayrintisi yok). */
    public record MyReportView(Long id, String targetType, String reason, String status, Instant createdAt,
                               Instant resolvedAt) {
        static MyReportView of(Report r) {
            return new MyReportView(r.getId(), r.getTargetType().name(), r.getReason().name(), r.getStatus().name(),
                    r.getCreatedAt(), r.getStatus() == Report.Status.RESOLVED ? r.getResolvedAt() : null);
        }
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
