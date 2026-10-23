package edu.bingol.backend.auth.jwt;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Authorization: Bearer <access token> basligini okuyup kimligi yerlestirir
 * (principal = kullanici id'si, yetki = ROLE_USER / ROLE_ADMIN).
 * Askiya alinan kullanicilar Redis'teki `suspended:<id>` anahtariyla aninda engellenir.
 */
public class JwtAuthFilter extends OncePerRequestFilter {

    public static final String SUSPENDED_KEY_PREFIX = "suspended:";

    private final JwtService jwt;
    private final StringRedisTemplate redis;

    public JwtAuthFilter(JwtService jwt, StringRedisTemplate redis) {
        this.jwt = jwt;
        this.redis = redis;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String h = req.getHeader("Authorization");
        if (h != null && h.startsWith("Bearer ")) {
            JwtService.Identity id = jwt.parse(h.substring(7).trim());
            if (id != null && !Boolean.TRUE.equals(redis.hasKey(SUSPENDED_KEY_PREFIX + id.userId()))) {
                SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                        id.userId(), null, List.of(new SimpleGrantedAuthority("ROLE_" + id.role().name()))));
            }
        }
        chain.doFilter(req, res);
    }
}
