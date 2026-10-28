package edu.bingol.backend.legal;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.legal.LegalDtos.PendingConsent;
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
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Yeni sozlesme surumu icin yeniden onay zorlamasi (KVKK/Kullanim Kosullari; denetim 2026-10-28 M41).
 * Kimligi dogrulanmis kullanicinin bekleyen onayi ({@link LegalService#pending}) varsa YAZMA/etkilesim istekleri
 * 403 {@code LEGAL_REACCEPT_REQUIRED} alir. Her zaman serbest: okuma (GET/HEAD/OPTIONS), kimlik/cikis
 * ({@code /api/auth/**}), sozlesme uclari ({@code /api/legal/**}), hesap silme ve veri indirme
 * ({@code /api/users/me}), destek, yonetim, analitik ve uygulama bilgisi. Ayar kapaliyken
 * ({@code app.legal.enforce-reaccept=false}, varsayilan) hicbir sey yapmaz: istemciler (mobil/web) onay ekranini
 * yayinlamadan acmayin. Sonuc "bekleyen yok" ise {@value #CLEAR_TTL_MS} ms bellekte tutulur (her yazmada DB sorgusu olmasin).
 */
@Component
@Order(Ordered.LOWEST_PRECEDENCE - 100)
public class LegalReacceptFilter extends OncePerRequestFilter {

    static final long CLEAR_TTL_MS = 60_000L;
    private static final int MAX_CACHE = 100_000;
    private static final Set<String> READ_METHODS = Set.of("GET", "HEAD", "OPTIONS", "TRACE");
    /** Muaf yol onekleri (segment siniri gozetilir): kimlik/cikis, sozlesme, destek, yonetim, analitik, uygulama bilgisi, cihaz kaydi. */
    private static final List<String> EXEMPT_PREFIXES = List.of(
            "/api/auth", "/api/legal", "/api/support", "/api/public", "/api/admin", "/api/analytics", "/api/app", "/api/devices");

    private final LegalService legal;
    private final I18n i18n;
    private final boolean enabled;
    private final ConcurrentHashMap<Long, Long> clearUntil = new ConcurrentHashMap<>();

    public LegalReacceptFilter(LegalService legal, I18n i18n,
                               @Value("${app.legal.enforce-reaccept:false}") boolean enabled) {
        this.legal = legal;
        this.i18n = i18n;
        this.enabled = enabled;
    }

    /** Zorlama kapsaminda mi: yalniz /api/** yazma istekleri, muaf yollar disinda. */
    static boolean inScope(String method, String uri) {
        if (uri == null || !uri.startsWith("/api/") || READ_METHODS.contains(method)) {
            return false;
        }
        for (String p : EXEMPT_PREFIXES) {
            if (uri.equals(p) || uri.startsWith(p + "/")) {
                return false;
            }
        }
        // Hesap silme (DELETE /api/users/me) ve veri indirme: kullanici hakki, her zaman serbest
        return !(uri.equals("/api/users/me") || uri.startsWith("/api/users/me/export"));
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        return !enabled || !inScope(req.getMethod(), req.getRequestURI());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        Long uid = userId();
        if (uid == null || isClear(uid)) {
            chain.doFilter(req, res);
            return;
        }
        List<PendingConsent> pending;
        try {
            pending = legal.pending(uid, Lang.DEFAULT);
        } catch (RuntimeException e) {
            // Sozlesme sorgusu basarisizsa kullaniciyi kilitleme: istek devam eder
            chain.doFilter(req, res);
            return;
        }
        if (pending.isEmpty()) {
            markClear(uid);
            chain.doFilter(req, res);
            return;
        }
        String message = i18n.msg("error.LEGAL_REACCEPT_REQUIRED", lang(req.getHeader("Accept-Language")).locale());
        StringBuilder items = new StringBuilder();
        for (PendingConsent p : pending) {
            items.append(items.length() == 0 ? "" : ",")
                    .append("{\"type\":\"").append(p.type().name()).append("\",\"version\":").append(p.version()).append('}');
        }
        res.setStatus(HttpServletResponse.SC_FORBIDDEN);
        res.setContentType("application/json");
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        res.setHeader("Cache-Control", "no-store");
        res.getWriter().write("{\"code\":\"LEGAL_REACCEPT_REQUIRED\",\"message\":\"" + escape(message)
                + "\",\"requiresAcceptance\":[" + items + "]}");
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

    static Lang lang(String header) {
        if (header == null || header.isBlank()) {
            return Lang.DEFAULT;
        }
        return Lang.of(header.split(",")[0].split(";")[0]);
    }

    private static String escape(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
