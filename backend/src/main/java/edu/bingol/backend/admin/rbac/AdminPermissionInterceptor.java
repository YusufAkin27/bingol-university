package edu.bingol.backend.admin.rbac;

import edu.bingol.backend.common.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * /api/admin/** izin denetimi (P16): yol + yonteme gore gereken izin {@link AdminPermissionPolicy}'den, yoneticinin
 * profili {@link AdminProfileResolver}'dan gelir; izin yoksa 403 ADMIN_PERMISSION_DENIED. Tek yerde oldugu icin yeni
 * yonetici ucu da otomatik kapsanir (eslenmemis yol yalniz FULL). Denetim kaydindan SONRA, hiz sinirindan ONCE calisir.
 */
@Component
public class AdminPermissionInterceptor implements HandlerInterceptor {

    private final AdminProfileResolver resolver;

    public AdminPermissionInterceptor(AdminProfileResolver resolver) {
        this.resolver = resolver;
    }

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
        String method = req.getMethod();
        if ("OPTIONS".equalsIgnoreCase(method)) {
            return true;
        }
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        AdminProfileResolver.Resolved r = resolver.resolve(auth, req);
        AdminPermissionContext ctx = new AdminPermissionContext(r.profile(), r.pinned());
        AdminPermissionContext.put(req, ctx);
        String need = AdminPermissionPolicy.required(method, req.getRequestURI());
        if (!ctx.can(need)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ADMIN_PERMISSION_DENIED",
                    "Bu işlem için yetkiniz yok (gereken izin: " + need + ").", need);
        }
        return true;
    }
}
