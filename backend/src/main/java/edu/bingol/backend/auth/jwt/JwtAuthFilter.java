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
 * Rolu degisen kullanicinin eski token'i (role claim'i eskidir) `rolechg:<id>` isaretiyle reddedilir; kullanici
 * refresh ile yeni rolde token alir. Isaret access token omru (15 dk) kadar yasar.
 */
public class JwtAuthFilter extends OncePerRequestFilter {

    public static final String SUSPENDED_KEY_PREFIX = "suspended:";
    /** Deger: rol degisim aninin epoch saniyesi. */
    public static final String ROLE_CHANGED_KEY_PREFIX = "rolechg:";

    /** Deger: sifre degisimi / "tum cihazlardan cik" aninin epoch milisaniyesi (eski surumlerde saniye olabilir). */
    public static final String PASSWORD_CHANGED_KEY_PREFIX = "pwchg:";

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
            if (id != null && allowed(id)) {
                SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                        id.userId(), null, List.of(new SimpleGrantedAuthority("ROLE_" + id.role().name()))));
            }
        }
        chain.doFilter(req, res);
    }

    /** Tek Redis turunda hem askiya hem rol degisimi kontrolu. */
    private boolean allowed(JwtService.Identity id) {
        List<String> v = redis.opsForValue()
                .multiGet(List.of(SUSPENDED_KEY_PREFIX + id.userId(), ROLE_CHANGED_KEY_PREFIX + id.userId(),
                        PASSWORD_CHANGED_KEY_PREFIX + id.userId()));
        if (v == null) {
            return true;
        }
        if (v.get(0) != null) {
            return false;
        }
        long iat = id.issuedAt().getEpochSecond();
        return !tokenPredatesRoleChange(iat, at(v, 1)) && !tokenRevoked(id.issuedAtMillis(), at(v, 2));
    }

    private static String at(List<String> values, int index) {
        return index < values.size() ? values.get(index) : null;
    }

    /** iat saniye hassasiyetindedir: degisimden onceki saniyede uretilen token reddedilir. */
    static boolean tokenPredatesRoleChange(long issuedAtEpochSecond, String changedAt) {
        if (changedAt == null) {
            return false;
        }
        try {
            return issuedAtEpochSecond < Long.parseLong(changedAt);
        } catch (NumberFormatException e) {
            return false;
        }
    }

    /**
     * Oturum iptali ms hassasiyetindedir: iptal anindan once (veya ayni anda) uretilen token reddedilir, sonra
     * acilan oturum kabul edilir. Saniye cinsinden eski isaretler (&lt; 1e11) ms'ye cevrilir.
     */
    public static boolean tokenRevoked(long issuedAtMillis, String revokedAt) {
        if (revokedAt == null) {
            return false;
        }
        try {
            long r = Long.parseLong(revokedAt);
            if (r < 100_000_000_000L) {
                r = r * 1000 + 999;
            }
            return issuedAtMillis <= r;
        } catch (NumberFormatException e) {
            return false;
        }
    }
}
