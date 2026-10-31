package edu.bingol.backend.appinfo;

import edu.bingol.backend.admin.AdminReasonRequired;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.appinfo.AppInfoService.EnforceChange;
import edu.bingol.backend.appinfo.AppInfoService.EnforceMode;
import edu.bingol.backend.appinfo.AppVersionAdminService.VersionDistribution;
import edu.bingol.backend.appinfo.AppVersionAdminService.VersionPlatformSummary;
import edu.bingol.backend.common.RateLimiter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici: uygulama surum dagilimi ve tek tikla surum zorlama (izin: settings.read / settings.write).
 * Zorlama GEREKCE ister (govde `reason` ya da X-Admin-Reason) ve AuditInterceptor ile denetlenir.
 * Sozlesme: docs/ADMIN_API.md "Uygulama guncelleme zorlama (UPDATEGATE)".
 */
@RestController
@RequestMapping("/api/admin/app-versions")
public class AppVersionAdminController {

    private static final Logger log = LoggerFactory.getLogger(AppVersionAdminController.class);

    public record EnforceRequest(@NotBlank @Size(max = 8) String platform, @Size(max = 32) String version,
                                 @NotNull EnforceMode mode, @Size(max = 300) String reason) {}

    /**
     * Zorlama sonucu. `affectedDevices`: FORCE'ta zorunlu guncelleme ekranini gorecek, SOFT'ta oneri alacak (OFF'ta 0)
     * cihaz sayisi; sayim kaynagi {@link AppVersionAdminService#SOURCE_NOTE}. Sayim basarisizsa null (ayar yine de yazildi).
     */
    public record EnforceResponse(String platform, EnforceMode mode, String state, String minVersion,
                                  String latestVersion, String previousMin, String previousLatest,
                                  Long affectedDevices, Long platformDevices, String source, String sourceNote) {}

    private final AppInfoService service;
    private final AppVersionAdminService stats;
    private final RateLimiter limiter;

    public AppVersionAdminController(AppInfoService service, AppVersionAdminService stats, RateLimiter limiter) {
        this.service = service;
        this.stats = stats;
        this.limiter = limiter;
    }

    @GetMapping
    public VersionDistribution distribution() {
        limiter.check("admin:appver:" + actor(), 60, Duration.ofMinutes(1));
        return stats.distribution();
    }

    @AdminReasonRequired
    @PostMapping("/enforce")
    public EnforceResponse enforce(@Valid @RequestBody EnforceRequest r) {
        limiter.check("admin:appver:w:" + actor(), 20, Duration.ofHours(1));
        AuditContext.target("APP_VERSION", r.platform().toLowerCase(java.util.Locale.ROOT));
        EnforceChange c = service.enforce(r.platform(), r.version(), r.mode());
        AuditContext.summary(r.mode() + " " + c.platform() + ": min " + c.previousMin() + " -> " + c.min()
                + ", latest " + c.previousLatest() + " -> " + c.latest());
        Long affected = null;
        Long total = null;
        try {
            VersionDistribution d = stats.distribution();
            VersionPlatformSummary ps = d.platforms().stream().filter(p -> p.platform().equals(c.platform())).findFirst()
                    .orElse(null);
            if (ps != null) {
                total = ps.total();
                affected = switch (r.mode()) {
                    case FORCE -> ps.belowMin();
                    case SOFT -> ps.belowLatest();
                    case OFF -> 0L;
                };
            }
        } catch (RuntimeException e) {
            log.warn("Surum dagilimi hesaplanamadi (ayar yazildi): {}", e.toString());
        }
        String state = new AppInfoService.PlatformVersions(c.platform(), c.min(), c.latest()).state();
        return new EnforceResponse(c.platform(), c.mode(), state, c.min(), c.latest(), c.previousMin(),
                c.previousLatest(), affected, total, AppVersionAdminService.SOURCE,
                AppVersionAdminService.SOURCE_NOTE);
    }

    private static String actor() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long id ? String.valueOf(id) : "basic";
    }
}
