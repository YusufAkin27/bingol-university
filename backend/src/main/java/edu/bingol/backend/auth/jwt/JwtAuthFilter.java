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
    /** Deger: rol degisim aninin epoch milisaniyesi (eski surumlerde saniye olabilir; < 1e11 ise saniye sayilir). */
    public static final String ROLE_CHANGED_KEY_PREFIX = "rolechg:";

    /** Deger: sifre degisimi / "tum cihazlardan cik" aninin epoch milisaniyesi (eski surumlerde saniye olabilir). */
    public static final String PASSWORD_CHANGED_KEY_PREFIX = "pwchg:";

    /** Deger: mobil oturumlarin iptal aninin epoch ms'i (tek cihaz kurali); yalniz cl=mobile token'lara uygulanir. */
    public static final String MOBILE_REVOKED_KEY_PREFIX = "pwchgm:";

    /** Token imzali ve suresi icinde ama oturumu iptal edilmis: giris noktasi 401 SESSION_REPLACED yazar. */
    public static final String SESSION_REPLACED_ATTR = "auth.sessionReplaced";

    /** Istek niteligi: token'daki yonetici profili talebi (P16; yoksa null) ve e-posta talebi. */
    public static final String ADMIN_PROFILE_ATTR = "auth.adminProfile";
    public static final String TOKEN_EMAIL_ATTR = "auth.tokenEmail";

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
            if (id != null) {
                Verdict v = check(id);
                if (v == Verdict.OK) {
                    req.setAttribute(ADMIN_PROFILE_ATTR, id.adminProfile());
                    req.setAttribute(TOKEN_EMAIL_ATTR, id.email());
                    SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                            id.userId(), null, List.of(new SimpleGrantedAuthority("ROLE_" + id.role().name()))));
                } else if (v == Verdict.REPLACED) {
                    req.setAttribute(SESSION_REPLACED_ATTR, Boolean.TRUE);
                }
            }
        }
        chain.doFilter(req, res);
    }

    private enum Verdict { OK, DENIED, REPLACED }

    /** Tek Redis turunda askiya, rol degisimi ve oturum iptali (genel + mobil) kontrolu. */
    private Verdict check(JwtService.Identity id) {
        List<String> v = redis.opsForValue()
                .multiGet(List.of(SUSPENDED_KEY_PREFIX + id.userId(), ROLE_CHANGED_KEY_PREFIX + id.userId(),
                        PASSWORD_CHANGED_KEY_PREFIX + id.userId(), MOBILE_REVOKED_KEY_PREFIX + id.userId()));
        if (v == null) {
            return Verdict.OK;
        }
        if (v.get(0) != null) {
            return Verdict.DENIED;
        }
        if (tokenRevoked(id.issuedAtMillis(), at(v, 2))
                || ("mobile".equals(id.client()) && tokenRevoked(id.issuedAtMillis(), at(v, 3)))) {
            return Verdict.REPLACED;
        }
        return tokenPredatesRoleChangeMs(id.issuedAtMillis(), at(v, 1)) ? Verdict.DENIED : Verdict.OK;
    }

    private static String at(List<String> values, int index) {
        return index < values.size() ? values.get(index) : null;
    }

    /**
     * ms hassasiyeti: isaret ms ise token'in iatms'i isaretten KESIN kucukse (rol degisiminden once uretildiyse)
     * reddedilir; saniye cinsinden eski isaretlerde (&lt; 1e11) saniye karsilastirmasi korunur.
     */
    static boolean tokenPredatesRoleChangeMs(long issuedAtMillis, String changedAt) {
        if (changedAt == null) {
            return false;
        }
        try {
            long r = Long.parseLong(changedAt);
            return r < 100_000_000_000L ? issuedAtMillis / 1000 < r : issuedAtMillis < r;
        } catch (NumberFormatException e) {
            return false;
        }
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
