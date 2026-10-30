package edu.bingol.backend.common;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

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

    public static boolean isAdmin() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getAuthorities().stream().anyMatch(g -> g.getAuthority().equals("ROLE_ADMIN"));
    }
}
