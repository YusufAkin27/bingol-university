package edu.bingol.backend.auth.jwt;

import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import javax.crypto.SecretKey;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/** Kisa omurlu access token (JWT, HS256). Refresh token'lar opak ve Redis'te tutulur (RefreshTokenService). */
@Service
public class JwtService {

    /** Gecerli bir token'dan okunan kimlik. */
    public record Identity(Long userId, Role role, Instant issuedAt, long issuedAtMillis, String client,
                           String email, String adminProfile) {
        /** Eski 5 alanli kurucu (yonetici profili/e-posta talepsiz). */
        public Identity(Long userId, Role role, Instant issuedAt, long issuedAtMillis, String client) {
            this(userId, role, issuedAt, issuedAtMillis, client, null, null);
        }
    }

    private static final Logger log = LoggerFactory.getLogger(JwtService.class);
    /** iat saniye hassasiyetinde oldugu icin oturum iptali karsilastirmasinda kullanilan ms hassasiyetli ek talep. */
    static final String IAT_MS_CLAIM = "iatms";
    /** Istemci turu talebi: mobile | web (talepsiz eski token'lar web sayilir). */
    static final String CLIENT_CLAIM = "cl";
    /** Yonetici profili talebi (P16): yalniz role=ADMIN token'larinda; izinler sunucuda profilden cozulur. */
    static final String ADMIN_PROFILE_CLAIM = "ap";
    private static final String DEV_SECRET_PREFIX = "dev-only-secret";

    private final SecretKey key;
    private final Duration accessTtl;

    public JwtService(JwtProperties props) {
        String secret = props.secret();
        byte[] bytes = secret.getBytes(StandardCharsets.UTF_8);
        if (bytes.length < 32) {
            throw new IllegalStateException("jwt.secret en az 32 karakter olmali");
        }
        if (secret.startsWith(DEV_SECRET_PREFIX)) {
            log.warn("Varsayilan gelistirme JWT anahtari kullaniliyor; uretimde JWT_SECRET verin!");
        }
        this.key = Keys.hmacShaKeyFor(bytes);
        this.accessTtl = Duration.ofMinutes(props.accessTtlMinutes());
    }

    public Duration accessTtl() {
        return accessTtl;
    }

    public String createAccessToken(User user) {
        return createAccessToken(user, "web");
    }

    public String createAccessToken(User user, String client) {
        Date now = new Date();
        var builder = Jwts.builder()
                .subject(String.valueOf(user.getId()))
                .claim("email", user.getEmail())
                .claim("role", user.getRole().name());
        if (user.getRole() == Role.ADMIN) {
            // Profili bos yonetici (migrasyon oncesi) FULL sayilir
            var p = user.getAdminProfile();
            builder.claim(ADMIN_PROFILE_CLAIM, (p == null ? edu.bingol.backend.admin.rbac.AdminProfile.FULL : p).name());
        }
        return builder
                .claim(CLIENT_CLAIM, "mobile".equalsIgnoreCase(client) ? "mobile" : "web")
                .claim(IAT_MS_CLAIM, now.getTime())
                .issuedAt(now)
                .expiration(new Date(now.getTime() + accessTtl.toMillis()))
                .signWith(key)
                .compact();
    }

    /** Gecerliyse kimligi doner, degilse null. */
    public Identity parse(String token) {
        try {
            Claims c = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
            String role = c.get("role", String.class);
            Date iat = c.getIssuedAt();
            Long ms = c.get(IAT_MS_CLAIM, Long.class);
            long iatMs = ms != null ? ms : (iat == null ? 0L : iat.getTime());
            return new Identity(Long.valueOf(c.getSubject()), role == null ? Role.USER : Role.valueOf(role),
                    iat == null ? Instant.EPOCH : iat.toInstant(), iatMs,
                    "mobile".equals(c.get(CLIENT_CLAIM, String.class)) ? "mobile" : "web",
                    c.get("email", String.class), c.get(ADMIN_PROFILE_CLAIM, String.class));
        } catch (JwtException | IllegalArgumentException e) {
            return null;
        }
    }
}
