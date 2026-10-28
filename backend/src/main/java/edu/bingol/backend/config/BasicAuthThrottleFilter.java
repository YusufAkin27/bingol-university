package edu.bingol.backend.config;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Basic auth ile gelen yonetici isteklerini sinirlar (parola kaba kuvvetine karsi). Uc katman:
 * 1) IP (IPv6 /64) basina istek sinirli (15 dk'da 120): betik kullanimini bozmaz;
 * 2) BASARISIZ deneme sayaci: IP basina 10, kullanici adi basina (IP'den bagimsiz) 30 / 15 dk; dolunca 429.
 *    Basarili giris IP sayacini sifirlar. Kullanici adi sabit oldugundan sayac dagitik denemeyi de yakalar;
 * 3) Redis erisilemezse FAIL-CLOSED (503): Basic yalniz acil durum girisidir, Redis'siz sinirsiz denemeye acilmaz.
 * Denetimde aktor `basic-admin` yazilir (bkz. admin.AuditRecorder).
 */
public class BasicAuthThrottleFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(BasicAuthThrottleFilter.class);
    static final int IP_FAIL_MAX = 10;
    static final int USER_FAIL_MAX = 30;
    static final Duration WINDOW = Duration.ofMinutes(15);

    private final RateLimiter limiter;
    private final ClientIp clientIp;
    private final StringRedisTemplate redis;
    /** Redis erisilemezse true: 503 (varsayilan); false: sinirlayici atlanir (yalniz Redis'siz testler). */
    private final boolean failClosed;

    public BasicAuthThrottleFilter(RateLimiter limiter, ClientIp clientIp, StringRedisTemplate redis) {
        this(limiter, clientIp, redis, true);
    }

    public BasicAuthThrottleFilter(RateLimiter limiter, ClientIp clientIp, StringRedisTemplate redis,
                                   boolean failClosed) {
        this.failClosed = failClosed;
        this.limiter = limiter;
        this.clientIp = clientIp;
        this.redis = redis;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String h = req.getHeader("Authorization");
        if (h == null || !h.regionMatches(true, 0, "Basic ", 0, 6)) {
            chain.doFilter(req, res);
            return;
        }
        String ip = clientIp.limitKey(req);
        String ipFail = "adminbasic:fail:ip:" + ip;
        String userFail = "adminbasic:fail:user:" + Hashing.sha256(username(h)).substring(0, 16);
        try {
            limiter.check("adminbasic:ip:" + ip, 120, Duration.ofMinutes(15));
            if (count(ipFail) >= IP_FAIL_MAX || count(userFail) >= USER_FAIL_MAX) {
                throw new edu.bingol.backend.common.RateLimitedException(WINDOW.toSeconds());
            }
        } catch (ApiException e) {
            res.setStatus(429);
            res.setContentType("application/json");
            res.getWriter().write("{\"code\":\"RATE_LIMITED\",\"message\":\"Too many attempts\"}");
            return;
        } catch (RuntimeException e) {
            if (!failClosed) {
                log.warn("Basic auth limiti kontrol edilemedi, istek gecirildi (fail-closed kapali): {}", e.toString());
                chain.doFilter(req, res);
                return;
            }
            log.warn("Basic auth limiti kontrol edilemedi, istek reddedildi: {}", e.toString());
            res.setStatus(503);
            res.setContentType("application/json");
            res.getWriter().write("{\"code\":\"UNAVAILABLE\",\"message\":\"Try again later\"}");
            return;
        }
        chain.doFilter(req, res);
        try {
            if (res.getStatus() == 401) {
                bump(ipFail);
                bump(userFail);
            } else if (res.getStatus() < 400) {
                redis.delete(ipFail);
            }
        } catch (RuntimeException e) {
            log.warn("Basic auth basarisiz deneme sayaci yazilamadi: {}", e.toString());
        }
    }

    private long count(String key) {
        String v = redis.opsForValue().get(key);
        try {
            return v == null ? 0 : Long.parseLong(v);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private void bump(String key) {
        Long n = redis.opsForValue().increment(key);
        if (n != null && n == 1) {
            redis.expire(key, WINDOW);
        }
    }

    /** Basic basligindaki kullanici adi (bozuksa bos); yalniz sayac anahtari icin (ozetlenir, log'lanmaz). */
    static String username(String header) {
        try {
            String decoded = new String(Base64.getDecoder().decode(header.substring(6).trim()), StandardCharsets.UTF_8);
            int i = decoded.indexOf(':');
            String u = i < 0 ? decoded : decoded.substring(0, i);
            return u.length() > 64 ? u.substring(0, 64) : u.toLowerCase(java.util.Locale.ROOT);
        } catch (IllegalArgumentException e) {
            return "";
        }
    }
}
