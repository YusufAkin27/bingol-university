package edu.bingol.backend.config;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Basic auth ile gelen yonetici isteklerini IP basina sinirlar (parola kaba kuvvetine karsi). Sinir genis tutuldu
 * (15 dk'da 120): betik kullanimini bozmaz, deneme-yanilmayi yavaslatir. Redis erisilemezse istek gecer.
 */
public class BasicAuthThrottleFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(BasicAuthThrottleFilter.class);

    private final RateLimiter limiter;
    private final ClientIp clientIp;

    public BasicAuthThrottleFilter(RateLimiter limiter, ClientIp clientIp) {
        this.limiter = limiter;
        this.clientIp = clientIp;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String h = req.getHeader("Authorization");
        if (h != null && h.regionMatches(true, 0, "Basic ", 0, 6)) {
            try {
                limiter.check("adminbasic:ip:" + clientIp.of(req), 120, Duration.ofMinutes(15));
            } catch (ApiException e) {
                res.setStatus(429);
                res.setContentType("application/json");
                res.getWriter().write("{\"code\":\"RATE_LIMITED\",\"message\":\"Too many attempts\"}");
                return;
            } catch (RuntimeException e) {
                log.warn("Basic auth limiti kontrol edilemedi: {}", e.toString());
            }
        }
        chain.doFilter(req, res);
    }
}
