package edu.bingol.backend.common;

import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.admin.rbac.PermissionMatrix;
import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/** Istegi yapan kullanici (JWT filtresi principal olarak Long id koyar). */
public final class CurrentUser {

    private CurrentUser() {}

    /** Giris yoksa 401 firlatir. */
    public static Long id() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        if (a == null || !(a.getPrincipal() instanceof Long id)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHORIZED", "Giriş gerekli.");
        }
        return id;
    }

    /** Giris yoksa null (401 firlatmaz; arama gibi kisisellestirmenin istege bagli oldugu yerler icin). */
    public static Long idOrNull() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long id ? id : null;
    }

    /**
     * Rol ADMIN mi. DIKKAT: yonetici profili (RBAC) bunu izne cevirmez; kullanici API'lerinde yonetici mudahalesi icin
     * {@link #adminPermissions()} / {@link #hasAdminPermission(String)} kullanin (VIEWER profili de ROLE_ADMIN tasir).
     */
    public static boolean isAdmin() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getAuthorities().stream().anyMatch(g -> g.getAuthority().equals("ROLE_ADMIN"));
    }

    /**
     * Gecerli istegin yonetici izinleri (JWT `ap` talebi + {@link PermissionMatrix}); ADMIN degilse bos. Talep yoksa
     * (P16 oncesi eski token, istek baglami disi) kapali basarisiz olur: bos kume. Basic auth yoneticisi her zaman FULL.
     */
    public static Set<String> adminPermissions() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        if (a == null || a.getAuthorities().stream().noneMatch(g -> g.getAuthority().equals("ROLE_ADMIN"))) {
            return Set.of();
        }
        if (!(a.getPrincipal() instanceof Long)) {
            return PermissionMatrix.permissionsOf(AdminProfile.FULL); // Basic auth yoneticisi
        }
        RequestAttributes ra = RequestContextHolder.getRequestAttributes();
        if (ra instanceof ServletRequestAttributes sra) {
            AdminProfile claim = AdminProfile.parse((String) sra.getRequest().getAttribute(JwtAuthFilter.ADMIN_PROFILE_ATTR));
            if (claim != null) {
                return PermissionMatrix.permissionsOf(claim);
            }
        }
        return Set.of();
    }

    /** ROLE_ADMIN ve profili bu izne sahip mi. */
    public static boolean hasAdminPermission(String perm) {
        return adminPermissions().contains(perm);
    }
}
