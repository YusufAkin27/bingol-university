package edu.bingol.backend.crash;

import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.admin.AdminReasonRequired;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.crash.CrashDtos.GroupDetail;
import edu.bingol.backend.crash.CrashDtos.GroupRow;
import edu.bingol.backend.crash.CrashDtos.StatusRequest;
import edu.bingol.backend.crash.CrashDtos.Summary;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Cokme raporlari yonetimi (yalniz ADMIN; izin: system.read / system.write). Durum degisikligi ve silme GEREKCE ister
 * (govde `reason` ya da X-Admin-Reason); yazma uclari AuditInterceptor ile denetlenir.
 * Sozlesme: docs/ADMIN_API.md "Cokme raporlari (CR1)".
 */
@RestController
@RequestMapping("/api/admin/crashes")
public class CrashAdminController {

    private final CrashAdminService service;
    private final RateLimiter limiter;

    public CrashAdminController(CrashAdminService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping
    public PageResponse<GroupRow> list(@RequestParam(required = false) String status,
                                       @RequestParam(required = false) String platform,
                                       @RequestParam(required = false) String version,
                                       @RequestParam(required = false) String q,
                                       @RequestParam(defaultValue = "lastSeen") String sort,
                                       @RequestParam(defaultValue = "0") int page,
                                       @RequestParam(defaultValue = "20") int size) {
        limiter.check("admin:crash:" + actor(), 120, Duration.ofMinutes(1));
        return service.list(status, platform, version, q, sort, page, size);
    }

    @GetMapping("/summary")
    public Summary summary() {
        limiter.check("admin:crash:" + actor(), 120, Duration.ofMinutes(1));
        return service.summary();
    }

    @GetMapping("/{id}")
    public GroupDetail detail(@PathVariable long id) {
        limiter.check("admin:crash:" + actor(), 120, Duration.ofMinutes(1));
        AuditContext.target("CRASH_GROUP", id);
        return service.detail(id);
    }

    @AdminReasonRequired
    @PatchMapping("/{id}/status")
    public GroupDetail setStatus(@PathVariable long id, @Valid @RequestBody StatusRequest r) {
        AuditContext.target("CRASH_GROUP", id).summary("durum: " + r.status());
        String reason = r.reason() != null && !r.reason().isBlank() ? r.reason() : AuditContext.currentReason();
        return service.setStatus(id, r.status(), reason, r.fixedInVersion(), actorLabel());
    }

    @AdminReasonRequired
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable long id) {
        AuditContext.target("CRASH_GROUP", id).summary("cokme grubu silindi");
        service.delete(id);
    }

    private static String actor() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long id ? String.valueOf(id) : "basic";
    }

    private static String actorLabel() {
        String a = actor();
        return "basic".equals(a) ? "basic-admin" : "admin:" + a;
    }
}
