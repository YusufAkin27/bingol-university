package edu.bingol.backend.auth;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Kota asiminda ERTELENMIS e-posta dogrulama (QT-BE) icin YALNIZ OKUMA modu. Kimligi dogrulanmis kullanici
 * {@code verification_deferred AND NOT email_verified} ise {@code /api/**} altindaki yazma istekleri (GET/HEAD/OPTIONS
 * disindakiler) 403 {@code EMAIL_VERIFICATION_REQUIRED} alir. Gerekce: dogrulanmamis hesap baskasinin e-posta
 * adresiyle acilmis olabilir (kimlik taklidi); adres sahibi kodu girene kadar topluluga yazamaz.
 *
 * <p>Serbest yazmalar ({@link #EXEMPT_PREFIXES} + profil/avatar/hesap silme): kimlik/cikis/dogrulama
 * ({@code /api/auth/**}, 2FA hariç), sozlesme onayi, cihaz/push kaydi, analitik, uygulama bilgisi/cokme raporu, destek
 * talebi, sikayet, kendi bildirim durumu. Gerisi 403. Mesajlasma STOMP kanali bu filtreden gecmez; ertelenmis hesap
 * hicbir sohbetin uyesi olamaz (sohbet baslatma/ekleme HTTP'de ve {@code ConversationService}'te dogrulanmis uye ister),
 * bu nedenle {@code chat.send} zaten uye olmadigi icin reddedilir.
 *
 * <p>Sonuc "kisitli degil" ise {@value #CLEAR_TTL_MS} ms bellekte tutulur (dogrulanmis hesap hicbir zaman ertelenmise
 * donmez); kisitli sonuc ONBELLEKLENMEZ (dogrulama aninda kisit kalksin, her yazmada tek PK sorgusu).
 */
@Component
@Order(Ordered.LOWEST_PRECEDENCE - 110)
public class UnverifiedWriteFilter extends OncePerRequestFilter {

    static final long CLEAR_TTL_MS = 600_000L;
    private static final int MAX_CACHE = 100_000;
    private static final Set<String> READ_METHODS = Set.of("GET", "HEAD", "OPTIONS", "TRACE");
    /** Kisitli modda da yazilabilen yol onekleri (segment siniri gozetilir). */
    static final List<String> EXEMPT_PREFIXES = List.of(
            "/api/auth", "/api/legal", "/api/support", "/api/public", "/api/analytics", "/api/app", "/api/devices",
            "/api/reports", "/api/notifications");
    /** /api/auth altinda yine KISITLI olanlar (2FA kodu mail kotasi harcar; dogrulanmamis hesap 2FA acamaz). */
    private static final String AUTH_2FA = "/api/auth/2fa";

    private final JdbcTemplate jdbc;
    private final I18n i18n;
    private final boolean enabled;
    private final ConcurrentHashMap<Long, Long> clearUntil = new ConcurrentHashMap<>();

    public UnverifiedWriteFilter(JdbcTemplate jdbc, I18n i18n,
                                 @Value("${app.auth.deferred-verification.enabled:true}") boolean enabled) {
        this.jdbc = jdbc;
        this.i18n = i18n;
        this.enabled = enabled;
    }

    /** Kisitli kullanici icin bu istek engellenecek mi (yalniz /api/** yazma istekleri, serbest yollar disinda). */
    static boolean blockedForUnverified(String method, String uri) {
        if (uri == null || !uri.startsWith("/api/") || READ_METHODS.contains(method)) {
            return false;
        }
        if (uri.equals(AUTH_2FA) || uri.startsWith(AUTH_2FA + "/")) {
            return true;
        }
        for (String p : EXEMPT_PREFIXES) {
            if (uri.equals(p) || uri.startsWith(p + "/")) {
                return false;
            }
        }
        // Kendi profili: ad/bolum/sinif duzenleme (PATCH), avatar, hesap silme (DELETE). /users/me altindaki gerisi kisitli.
        String m = method == null ? "" : method;
        if (uri.equals("/api/users/me")) {
            return !(m.equals("PATCH") || m.equals("DELETE"));
        }
        if (uri.equals("/api/users/me/avatar")) {
            return !(m.equals("POST") || m.equals("DELETE"));
        }
        return true;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        return !enabled || !blockedForUnverified(req.getMethod(), req.getRequestURI());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        Long uid = userId();
        if (uid == null || isClear(uid)) {
            chain.doFilter(req, res);
            return;
        }
        boolean restricted;
        try {
            restricted = isRestricted(uid);
        } catch (RuntimeException e) {
            // Sorgu basarisizsa kullaniciyi kilitleme: istek devam eder (yazma uclari kendi kimlik kontrollerini yapar)
            chain.doFilter(req, res);
            return;
        }
        if (!restricted) {
            markClear(uid);
            chain.doFilter(req, res);
            return;
        }
        String message = i18n.msg("error.EMAIL_VERIFICATION_REQUIRED", lang(req.getHeader("Accept-Language")).locale());
        res.setStatus(HttpServletResponse.SC_FORBIDDEN);
        res.setContentType("application/json");
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        res.setHeader("Cache-Control", "no-store");
        res.getWriter().write("{\"code\":\"EMAIL_VERIFICATION_REQUIRED\",\"message\":\"" + escape(message) + "\"}");
    }

    private boolean isRestricted(Long uid) {
        List<Boolean> rows = jdbc.query(
                "SELECT (verification_deferred AND NOT email_verified) FROM app_user WHERE id = ?",
                (rs, n) -> rs.getBoolean(1), uid);
        return !rows.isEmpty() && Boolean.TRUE.equals(rows.get(0));
    }

    private static Long userId() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long id ? id : null;
    }

    private boolean isClear(Long uid) {
        Long until = clearUntil.get(uid);
        return until != null && until > System.currentTimeMillis();
    }

    private void markClear(Long uid) {
        if (clearUntil.size() > MAX_CACHE) {
            clearUntil.clear();
        }
        clearUntil.put(uid, System.currentTimeMillis() + CLEAR_TTL_MS);
    }

    public static Lang lang(String header) {
        if (header == null || header.isBlank()) {
            return Lang.DEFAULT;
        }
        return Lang.of(header.split(",")[0].split(";")[0]);
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
