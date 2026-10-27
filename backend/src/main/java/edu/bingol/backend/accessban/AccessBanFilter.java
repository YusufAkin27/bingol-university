package edu.bingol.backend.accessban;

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
 * En erken sunucu filtresi (Spring Security zincirinden once): engelli IP/CIDR, cihaz ve (ayar aciksa) anonimlestirici
 * agindan gelen TUM /api/** ve /ws istekleri anonim dahil 403 ACCESS_BLOCKED alir. Muaf: /api/admin/**
 * (yonetici kilitlenmesin), saglik denetimi, statik/diger yollar, OPTIONS on kontrolu. Loopback, ozel aglar ve
 * `app.security.ban-allowlist` hicbir zaman IP ile engellenmez. Kullanici engeli kimlik dogrulama sonrasi
 * ({@link AccessGuard}) uygulanir.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 20)
public class AccessBanFilter extends OncePerRequestFilter {

    private final ClientContexts contexts;
    private final AccessGuard guard;
    private final I18n i18n;

    public AccessBanFilter(ClientContexts contexts, AccessGuard guard, I18n i18n) {
        this.contexts = contexts;
        this.guard = guard;
        this.i18n = i18n;
    }

    /** Kapsam: /api/** (admin haric) ve /ws. */
    static boolean inScope(String method, String uri) {
        if ("OPTIONS".equals(method) || uri == null) {
            return false;
        }
        if (uri.equals("/ws") || uri.startsWith("/ws/")) {
            return true;
        }
        return uri.startsWith("/api/") && !uri.startsWith("/api/admin/") && !uri.equals("/api/admin");
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        return !inScope(req.getMethod(), req.getRequestURI());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        ClientContext ctx = contexts.of(req);
        if (guard.blocked(ctx, null, req.getRequestURI()) == null) {
            chain.doFilter(req, res);
            return;
        }
        String message = i18n.msg("error.ACCESS_BLOCKED", lang(req.getHeader("Accept-Language")).locale());
        res.setStatus(HttpServletResponse.SC_FORBIDDEN);
        res.setContentType("application/json");
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        res.setHeader("Cache-Control", "no-store");
        res.getWriter().write("{\"code\":\"ACCESS_BLOCKED\",\"message\":\"" + escape(message) + "\"}");
    }

    /** Accept-Language'in ilk etiketi ("ar,en;q=0.9" -> ar); bilinmeyen = tr. */
    static Lang lang(String header) {
        if (header == null || header.isBlank()) {
            return Lang.DEFAULT;
        }
        String first = header.split(",")[0].split(";")[0];
        return Lang.of(first);
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
