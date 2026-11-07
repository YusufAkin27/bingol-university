package edu.bingol.backend.auth.realemail;

import edu.bingol.backend.auth.UnverifiedWriteFilter;
import edu.bingol.backend.i18n.I18n;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Set;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Gercek e-posta kapisi (SUNUCU TARAFI): hesap Apple role adresiyle ACILDIYSA ve gercek adres henuz kodla
 * dogrulanmadiysa ({@link RealEmailGate}) {@code /api/**} altindaki YAZMA istekleri 403 {@code REAL_EMAIL_REQUIRED}
 * alir. Okuma uclari serbesttir. {@link edu.bingol.backend.auth.ProfileIncompleteWriteFilter} ile ayni kalip; ikisi
 * bagimsiz (profil tamamlama / gercek e-posta) calisir ve hangisinin once yapilacagi onemsizdir.
 *
 * <p>Serbest yazmalar: {@code /api/users/me/email/**} (gercek e-posta akisi), {@code PUT /api/users/me/onboarding},
 * avatar, kendi profili (PATCH) ve hesap silme (DELETE /api/users/me), kimlik/cikis ({@code /api/auth/**}), sozlesme
 * onayi, cihaz/push kaydi, analitik, uygulama bilgisi/cokme raporu, destek talebi, sikayet, bildirim durumu.
 * Mesajlasma STOMP SEND kanali bu suzgecten gecmez: {@code StompAuthInterceptor} ayni {@link RealEmailGate} ile reddeder.
 */
@Component
@Order(Ordered.LOWEST_PRECEDENCE - 106)
public class RealEmailRequiredWriteFilter extends OncePerRequestFilter {

    private static final Set<String> READ_METHODS = Set.of("GET", "HEAD", "OPTIONS", "TRACE");
    static final List<String> EXEMPT_PREFIXES = List.of(
            "/api/auth", "/api/legal", "/api/support", "/api/public", "/api/analytics", "/api/app", "/api/devices",
            "/api/reports", "/api/notifications", "/api/users/me/email");

    private final RealEmailGate gate;
    private final I18n i18n;

    public RealEmailRequiredWriteFilter(RealEmailGate gate, I18n i18n) {
        this.gate = gate;
        this.i18n = i18n;
    }

    /** Bu istek gercek e-postasi eksik hesap icin engellenecek mi (yalniz /api/** yazma istekleri, serbest yollar disinda). */
    static boolean blockedForRealEmail(String method, String uri) {
        if (uri == null || !uri.startsWith("/api/") || READ_METHODS.contains(method)) {
            return false;
        }
        for (String p : EXEMPT_PREFIXES) {
            if (uri.equals(p) || uri.startsWith(p + "/")) {
                return false;
            }
        }
        String m = method == null ? "" : method;
        if (uri.equals("/api/users/me/onboarding")) {
            return !m.equals("PUT");
        }
        if (uri.equals("/api/users/me/avatar")) {
            return !(m.equals("POST") || m.equals("DELETE"));
        }
        if (uri.equals("/api/users/me")) {
            return !(m.equals("PATCH") || m.equals("DELETE"));
        }
        return true;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        return !gate.enabled() || !blockedForRealEmail(req.getMethod(), req.getRequestURI());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        Long uid = userId();
        if (uid == null || !gate.isRequired(uid)) {
            chain.doFilter(req, res);
            return;
        }
        String message = i18n.msg("error.REAL_EMAIL_REQUIRED",
                UnverifiedWriteFilter.lang(req.getHeader("Accept-Language")).locale());
        res.setStatus(HttpServletResponse.SC_FORBIDDEN);
        res.setContentType("application/json");
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        res.setHeader("Cache-Control", "no-store");
        res.getWriter().write("{\"code\":\"REAL_EMAIL_REQUIRED\",\"message\":\"" + escape(message) + "\"}");
    }

    private static Long userId() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long id ? id : null;
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
