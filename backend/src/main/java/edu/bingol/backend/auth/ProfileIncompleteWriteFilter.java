package edu.bingol.backend.auth;

import edu.bingol.backend.i18n.I18n;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Profil tamamlama kapisi (SUNUCU TARAFI): kimligi dogrulanmis kullanicinin {@code profile_completed_at} degeri NULL ise
 * {@code /api/**} altindaki YAZMA istekleri (GET/HEAD/OPTIONS disindakiler) 403 {@code PROFILE_INCOMPLETE} alir. Istemci
 * tarafi yonlendirmesine guvenilmez: onboarding bitmeden gonderi/mesaj/katilim vb. hicbir etkilesim yapilamaz.
 *
 * <p>Serbest yazmalar: onboarding ({@code PUT /api/users/me/onboarding}), avatar yukleme/kaldirma, hesap silme
 * ({@code DELETE /api/users/me}), kimlik/cikis/baglama ({@code /api/auth/**}), sozlesme onayi, cihaz/push kaydi,
 * analitik, uygulama bilgisi/cokme raporu, destek talebi. {@link UnverifiedWriteFilter} ile ayni kalip; ikisi ayri
 * nedenlerle (dogrulanmamis e-posta / tamamlanmamis profil) bagimsiz calisir. Mesajlasma STOMP SEND kanali bu
 * suzgecten gecmez: {@code StompAuthInterceptor} ayni {@link ProfileCompletionGate} ile reddeder.
 */
@Component
@Order(Ordered.LOWEST_PRECEDENCE - 108)
public class ProfileIncompleteWriteFilter extends OncePerRequestFilter {

    private static final Set<String> READ_METHODS = Set.of("GET", "HEAD", "OPTIONS", "TRACE");
    /** Tamamlanmamis profilde de yazilabilen yol onekleri (segment siniri gozetilir). */
    static final List<String> EXEMPT_PREFIXES = List.of(
            "/api/auth", "/api/legal", "/api/support", "/api/public", "/api/analytics", "/api/app", "/api/devices");

    private final ProfileCompletionGate gate;
    private final I18n i18n;
    private final boolean enabled;

    public ProfileIncompleteWriteFilter(ProfileCompletionGate gate, I18n i18n,
                                        @Value("${app.auth.profile-gate.enabled:true}") boolean enabled) {
        this.gate = gate;
        this.i18n = i18n;
        this.enabled = enabled;
    }

    /** Bu istek tamamlanmamis profil icin engellenecek mi (yalniz /api/** yazma istekleri, serbest yollar disinda). */
    static boolean blockedForIncomplete(String method, String uri) {
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
            return !m.equals("DELETE");
        }
        return true;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        return !enabled || !blockedForIncomplete(req.getMethod(), req.getRequestURI());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        Long uid = userId();
        if (uid == null || !gate.isIncomplete(uid)) {
            chain.doFilter(req, res);
            return;
        }
        String message = i18n.msg("error.PROFILE_INCOMPLETE", UnverifiedWriteFilter.lang(req.getHeader("Accept-Language")).locale());
        res.setStatus(HttpServletResponse.SC_FORBIDDEN);
        res.setContentType("application/json");
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        res.setHeader("Cache-Control", "no-store");
        res.getWriter().write("{\"code\":\"PROFILE_INCOMPLETE\",\"message\":\"" + escape(message) + "\"}");
    }

    private static Long userId() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long id ? id : null;
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
