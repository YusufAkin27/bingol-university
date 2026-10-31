package edu.bingol.backend.admin.rbac;

import jakarta.servlet.http.HttpServletRequest;
import java.util.Set;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * Istek kapsamli yonetici yetki baglami: {@link AdminPermissionInterceptor} cozumlenen profili istege koyar; servisler
 * ({@link PermissionAwareMasking}) buradan okur. Istek disinda (birim testi, zamanlayici) baglam yoktur => kisitlama yok.
 */
public record AdminPermissionContext(AdminProfile profile, boolean pinned) {

    static final String ATTR = AdminPermissionContext.class.getName();

    public Set<String> permissions() {
        return PermissionMatrix.permissionsOf(profile);
    }

    public boolean can(String perm) {
        return PermissionMatrix.allows(profile, perm);
    }

    public static void put(HttpServletRequest req, AdminPermissionContext ctx) {
        req.setAttribute(ATTR, ctx);
    }

    /** Gecerli istegin baglami; yoksa null. */
    public static AdminPermissionContext current() {
        RequestAttributes ra = RequestContextHolder.getRequestAttributes();
        if (ra instanceof ServletRequestAttributes sra) {
            Object o = sra.getRequest().getAttribute(ATTR);
            return o instanceof AdminPermissionContext c ? c : null;
        }
        return null;
    }
}
