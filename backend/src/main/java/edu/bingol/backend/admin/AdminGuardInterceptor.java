package edu.bingol.backend.admin;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Yonetici yazma guvenligi (/api/admin/**): (1) yonetici basina yazma hiz siniri (dakikada 60) ve yikici islemlerde
 * saatlik sinir (20) -> 429 + Retry-After; (2) kritik islemlerde (rol, silme, sozlesme yayini, kritik ayar, toplu islem)
 * ve {@link AdminReasonRequired} uclarinda SEBEP zorunlulugu -> 400 REASON_REQUIRED.
 * Tek yerde oldugu icin yeni yonetici ucu de otomatik kapsanir. Sebep {@link AdminReasonFilter} ile AuditContext'e konur.
 */
@Component
public class AdminGuardInterceptor implements HandlerInterceptor {

    private final RateLimiter limiter;
    private final boolean requireReason;
    private final int writePerMinute;
    private final int destructivePerHour;

    public AdminGuardInterceptor(RateLimiter limiter,
                                 @Value("${app.admin.require-reason:true}") boolean requireReason,
                                 @Value("${app.admin.write-per-minute:60}") int writePerMinute,
                                 @Value("${app.admin.destructive-per-hour:20}") int destructivePerHour) {
        this.limiter = limiter;
        this.requireReason = requireReason;
        this.writePerMinute = writePerMinute;
        this.destructivePerHour = destructivePerHour;
    }

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
        String method = req.getMethod();
        String path = AdminPaths.of(req);
        if (AuditContext.of(req).reasonInvalid()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_INVALID",
                    "Gerekçe satır sonu veya kontrol karakteri içeremez.");
        }
        if (AdminGuardPolicy.isWrite(method)) {
            String actor = actorKey();
            limiter.check("admw:" + actor, writePerMinute, Duration.ofMinutes(1));
            if (AdminGuardPolicy.destructive(method, path)) {
                limiter.check("admd:" + actor, destructivePerHour, Duration.ofHours(1));
            }
        }
        if (requireReason) {
            int min = AdminGuardPolicy.reasonMin(method, path);
            if (handler instanceof HandlerMethod hm) {
                AdminReasonRequired a = hm.getMethodAnnotation(AdminReasonRequired.class);
                if (a == null) {
                    a = hm.getBeanType().getAnnotation(AdminReasonRequired.class);
                }
                if (a != null) {
                    min = Math.max(min, a.min());
                }
            }
            if (min > 0) {
                requireReason(AuditContext.of(req).reason(), min);
            }
        }
        return true;
    }

    /** Sebep yoksa ya da cok kisaysa 400 REASON_REQUIRED. */
    static void requireReason(String reason, int min) {
        if (reason == null || reason.strip().length() < min) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_REQUIRED",
                    "Bu işlem için gerekçe zorunludur (en az " + min + " karakter).", String.valueOf(min));
        }
    }

    /** Hiz siniri anahtari: JWT yoneticisi icin kimlik; Basic auth yoneticisi icin ortak "basic". */
    static String actorKey() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        if (a != null && a.getPrincipal() instanceof Long id) {
            return String.valueOf(id);
        }
        return "basic";
    }
}
