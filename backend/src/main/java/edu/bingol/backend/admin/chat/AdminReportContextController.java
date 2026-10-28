package edu.bingol.backend.admin.chat;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Sikayet detayi + baglami (`/api/admin/**` yalnizca ADMIN; kimlik JWT'den). Her cagri denetim kaydi uretir. */
@edu.bingol.backend.admin.AuditRead
@RestController
@RequestMapping("/api/admin/reports")
public class AdminReportContextController {

    private final AdminReportContextService service;
    private final RateLimiter limiter;

    public AdminReportContextController(AdminReportContextService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /** GET /api/admin/reports/{id}: sikayet + context + relatedReports + viewerPath. */
    @GetMapping("/{id}")
    public AdminReportContextService.ReportDetail detail(@PathVariable long id, HttpServletRequest http) {
        long adminId = CurrentUser.id();
        limiter.check("adminchat:" + adminId, AdminChatViewerController.PAGES_PER_MINUTE, Duration.ofMinutes(1));
        return service.detail(adminId, id, http.getRemoteAddr());
    }
}
