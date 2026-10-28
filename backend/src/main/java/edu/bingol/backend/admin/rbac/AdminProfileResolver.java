package edu.bingol.backend.admin.rbac;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.config.AdminProperties;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import java.util.Optional;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

/**
 * Istegi yapan yoneticinin profilini cozer. Sira: (1) Basic auth / kullanici kaydi olmayan kimlik => FULL
 * (geriye uyum); (2) ADMIN_EMAILS'teki hesap => her zaman FULL; (3) JWT `ap` talebi; (4) talep yoksa (eski token)
 * kullanici kaydi; kayitta profil bossa FULL (migrasyon oncesi yoneticiler).
 */
@Component
public class AdminProfileResolver {

    /** Cozumlenmis profil + sabitli (ADMIN_EMAILS) bilgisi. */
    public record Resolved(AdminProfile profile, boolean pinned) {}

    private final UserRepository users;
    private final AdminProperties adminProps;

    public AdminProfileResolver(UserRepository users, AdminProperties adminProps) {
        this.users = users;
        this.adminProps = adminProps;
    }

    public boolean isPinned(String email) {
        return email != null && adminProps != null && adminProps.isAdminEmail(email);
    }

    public Resolved resolve(Authentication auth, HttpServletRequest req) {
        if (auth == null || !(auth.getPrincipal() instanceof Long id)) {
            return new Resolved(AdminProfile.FULL, false); // Basic auth yoneticisi
        }
        AdminProfile claim = req == null ? null
                : AdminProfile.parse((String) req.getAttribute(JwtAuthFilter.ADMIN_PROFILE_ATTR));
        String email = req == null ? null : (String) req.getAttribute(JwtAuthFilter.TOKEN_EMAIL_ATTR);
        if (claim != null && email != null) {
            boolean pinned = isPinned(email);
            return new Resolved(pinned ? AdminProfile.FULL : claim, pinned);
        }
        Optional<User> u = users.findById(id);
        if (u.isEmpty()) {
            return new Resolved(AdminProfile.FULL, false); // kaydi olmayan kimlik (geriye uyum)
        }
        return forUser(u.get(), claim);
    }

    /** Kullanici kaydindan (ve varsa token talebinden) etkin profil. */
    public Resolved forUser(User u, AdminProfile claim) {
        boolean pinned = isPinned(u.getEmail());
        if (pinned) {
            return new Resolved(AdminProfile.FULL, true);
        }
        AdminProfile stored = u.getAdminProfile();
        // Kayit esastir (talep eskimis olabilir); kayitta yoksa token talebi, o da yoksa FULL (eski yoneticiler)
        return new Resolved(stored != null ? stored : claim != null ? claim : AdminProfile.FULL, false);
    }

    /** Kullanicinin etkin profili (yonetici listesi/kurallar icin). */
    public AdminProfile effective(User u) {
        return forUser(u, null).profile();
    }
}
