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
    public record Identity(Long userId, Role role, Instant issuedAt, long issuedAtMillis) {}

    private static final Logger log = LoggerFactory.getLogger(JwtService.class);
    /** iat saniye hassasiyetinde oldugu icin oturum iptali karsilastirmasinda kullanilan ms hassasiyetli ek talep. */
    static final String IAT_MS_CLAIM = "iatms";
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
        Date now = new Date();
        return Jwts.builder()
                .subject(String.valueOf(user.getId()))
                .claim("email", user.getEmail())
                .claim("role", user.getRole().name())
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
                    iat == null ? Instant.EPOCH : iat.toInstant(), iatMs);
        } catch (JwtException | IllegalArgumentException e) {
            return null;
        }
    }
}
