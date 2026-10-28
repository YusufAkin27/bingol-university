package edu.bingol.backend.common;

import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.util.ContentCachingResponseWrapper;

/**
 * Yonetici yazma uclari icin `Idempotency-Key` destegi (POST/PUT/PATCH/DELETE /api/admin/**; Spring Security'den SONRA).
 * Baslik yoksa ya da bicimsizse istek aynen islenir. Varsa Redis `idem:<yonetici>:<anahtar>` (SET NX, varsayilan 60 sn):
 * <ul>
 *   <li>ilk istek islenir; 2xx sonucu (durum + en cok {@value #MAX_BODY} bayt govde) saklanir, 2xx disi sonuc ANAHTARI
 *       SERBEST BIRAKIR (istemci duzeltip ayni anahtarla yeniden deneyebilir);</li>
 *   <li>ayni anahtarla gelen ikinci istek ilkinin bitmesini BEKLEMEZ: ilk bitene dek 409 REQUEST_IN_PROGRESS
 *       (+ Retry-After), bitince saklanan sonuc `Idempotency-Replayed: true` ile tekrar doner (buyuk govdede yalniz durum);</li>
 *   <li>ayni anahtar baska yol/yontemle gelirse 422 IDEMPOTENCY_KEY_REUSED;</li>
 *   <li>Redis erisilemezse fail-open: istek korumasiz islenir (denetim/yetki etkilenmez).</li>
 * </ul>
 */
@Component
@Order(Ordered.LOWEST_PRECEDENCE - 90)
public class IdempotencyFilter extends OncePerRequestFilter {

    public static final String HEADER = "Idempotency-Key";
    public static final String REPLAYED = "Idempotency-Replayed";
    static final int MAX_BODY = 16 * 1024;
    private static final Pattern KEY = Pattern.compile("[A-Za-z0-9._:-]{8,100}");
    private static final Logger log = LoggerFactory.getLogger(IdempotencyFilter.class);

    private final StringRedisTemplate redis;
    private final I18n i18n;
    private final Duration ttl;

    public IdempotencyFilter(StringRedisTemplate redis, I18n i18n,
                             @Value("${app.admin.idempotency-ttl-seconds:60}") long ttlSeconds) {
        this.redis = redis;
        this.i18n = i18n;
        this.ttl = Duration.ofSeconds(Math.max(5, ttlSeconds));
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest req) {
        String m = req.getMethod();
        boolean write = "POST".equals(m) || "PUT".equals(m) || "PATCH".equals(m) || "DELETE".equals(m);
        return !write || !req.getRequestURI().startsWith("/api/admin/") || req.getHeader(HEADER) == null;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String key = req.getHeader(HEADER).trim();
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || !KEY.matcher(key).matches()) {
            chain.doFilter(req, res);
            return;
        }
        String actor = auth.getPrincipal() instanceof Long id ? String.valueOf(id) : "basic";
        String rk = "idem:" + actor + ":" + key;
        String fp = Hashing.sha256(req.getMethod() + " " + req.getRequestURI()).substring(0, 16);

        boolean acquired;
        String existing = null;
        try {
            acquired = Boolean.TRUE.equals(redis.opsForValue().setIfAbsent(rk, "P:" + fp, ttl));
            if (!acquired) {
                existing = redis.opsForValue().get(rk);
            }
        } catch (RuntimeException e) {
            log.warn("Idempotency Redis hatasi (fail-open): {}", e.toString());
            chain.doFilter(req, res);
            return;
        }
        if (!acquired) {
            if (existing == null) { // iki okuma arasinda kayit zaman asimina ugradi: korumasiz isle
                chain.doFilter(req, res);
                return;
            }
            respondExisting(existing, fp, req, res);
            return;
        }

        ContentCachingResponseWrapper wrapped = new ContentCachingResponseWrapper(res);
        try {
            chain.doFilter(req, wrapped);
        } catch (IOException | ServletException | RuntimeException e) {
            release(rk);
            throw e;
        }
        int status = wrapped.getStatus();
        if (status >= 200 && status < 300) {
            store(rk, fp, status, wrapped);
        } else {
            release(rk);
        }
        wrapped.copyBodyToResponse();
    }

    private void store(String rk, String fp, int status, ContentCachingResponseWrapper w) {
        try {
            byte[] body = w.getContentAsByteArray();
            boolean truncated = body.length > MAX_BODY;
            String ct = w.getContentType() == null ? "" : w.getContentType();
            String v = "D:" + fp + ":" + status + ":" + (truncated ? "T" : "F") + ":"
                    + Base64.getEncoder().encodeToString(ct.getBytes(StandardCharsets.UTF_8)) + ":"
                    + (truncated ? "" : Base64.getEncoder().encodeToString(body));
            redis.opsForValue().set(rk, v, ttl);
        } catch (RuntimeException e) {
            log.warn("Idempotency sonucu saklanamadi: {}", e.toString());
        }
    }

    private void release(String rk) {
        try {
            redis.delete(rk);
        } catch (RuntimeException e) {
            log.warn("Idempotency anahtari silinemedi: {}", e.toString());
        }
    }

    private void respondExisting(String v, String fp, HttpServletRequest req, HttpServletResponse res)
            throws IOException {
        String[] p = v.split(":", 6);
        if (p.length < 2 || !p[1].equals(fp)) {
            error(req, res, 422, "IDEMPOTENCY_KEY_REUSED", 0);
            return;
        }
        if ("P".equals(p[0])) {
            error(req, res, 409, "REQUEST_IN_PROGRESS", 1);
            return;
        }
        if (p.length < 6) { // bozuk kayit: korumasiz degil, tekrar denenebilsin
            error(req, res, 409, "REQUEST_IN_PROGRESS", 1);
            return;
        }
        res.setStatus(Integer.parseInt(p[2]));
        res.setHeader(REPLAYED, "true");
        String ct = new String(Base64.getDecoder().decode(p[4]), StandardCharsets.UTF_8);
        if (!ct.isEmpty()) {
            res.setContentType(ct);
        }
        byte[] body = Base64.getDecoder().decode(p[5]);
        if (body.length > 0) {
            res.setContentLength(body.length);
            res.getOutputStream().write(body);
        }
    }

    private void error(HttpServletRequest req, HttpServletResponse res, int status, String code, int retryAfter)
            throws IOException {
        String header = req.getHeader("Accept-Language");
        Lang lang = header == null || header.isBlank() ? Lang.DEFAULT : Lang.of(header.split(",")[0].split(";")[0]);
        String message = i18n.msg("error." + code, lang.locale());
        res.setStatus(status);
        res.setContentType("application/json");
        res.setCharacterEncoding(StandardCharsets.UTF_8.name());
        res.setHeader("Cache-Control", "no-store");
        if (retryAfter > 0) {
            res.setHeader("Retry-After", String.valueOf(retryAfter));
        }
        res.getWriter().write("{\"code\":\"" + code + "\",\"message\":\""
                + message.replace("\\", "\\\\").replace("\"", "\\\"") + "\"}");
    }
}
