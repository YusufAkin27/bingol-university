package edu.bingol.backend.admin;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Ek savunma (T-010): /api/admin/** yolunda `%40` (e-posta '@') disinda yuzde-kodlu karakter varsa 400 ADMIN_PATH_INVALID.
 * Asil duzeltme {@link AdminPaths} ile cozulmus yoldur; bu filtre kodlu segmentle yapilan yetki/denetim atlatma
 * denemelerini kokunden reddeder ve olagan istemcilerin (web paneli, mobil) hicbir zaman uretmedigi yollari keser.
 * Yolda '%' yoksa maliyetsizdir (tek indexOf).
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 15)
public class AdminPathGuardFilter extends OncePerRequestFilter {

    private final I18n i18n;

    public AdminPathGuardFilter(I18n i18n) {
        this.i18n = i18n;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        String raw = req.getRequestURI();
        if (raw == null || raw.indexOf('%') < 0) {
            return true;
        }
        return !(raw.startsWith(AdminPaths.PREFIX) || AdminPaths.isAdmin(AdminPaths.of(req)));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        if (!AdminPaths.hasUnsafeEncoding(req.getRequestURI())) {
            chain.doFilter(req, res);
            return;
        }
        String message = i18n.msg("error.ADMIN_PATH_INVALID", lang(req.getHeader("Accept-Language")).locale());
        res.setStatus(HttpServletResponse.SC_BAD_REQUEST);
        res.setContentType("application/json");
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        res.setHeader("Cache-Control", "no-store");
        res.getWriter().write("{\"code\":\"ADMIN_PATH_INVALID\",\"message\":\"" + escape(message) + "\"}");
    }

    private static Lang lang(String header) {
        if (header == null || header.isBlank()) {
            return Lang.DEFAULT;
        }
        return Lang.of(header.split(",")[0].split(";")[0]);
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
