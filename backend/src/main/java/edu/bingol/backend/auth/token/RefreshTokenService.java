package edu.bingol.backend.auth.token;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.config.JwtProperties;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.Set;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

/**
 * Opak refresh token: Redis'te yalnizca SHA-256 ozeti saklanir. Her kullanimda doner (rotation);
 * eski token tek kullanimliktir. Kullanici basina `rtu:<uid>` kumesi token ozetlerini indeksler;
 * boylece tum oturumlar tek hamlede kapatilabilir.
 */
@Service
public class RefreshTokenService {

    private static final String TOKEN_PREFIX = "rt:";

    private final StringRedisTemplate redis;
    private final Duration ttl;
    private final SecureRandom random = new SecureRandom();

    public RefreshTokenService(StringRedisTemplate redis, JwtProperties props) {
        this.redis = redis;
        this.ttl = Duration.ofDays(props.refreshTtlDays());
    }

    public String issue(Long userId) {
        byte[] b = new byte[32];
        random.nextBytes(b);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(b);
        String hash = Hashing.sha256(token);
        redis.opsForValue().set(TOKEN_PREFIX + hash, String.valueOf(userId), ttl);
        redis.opsForSet().add(userKey(userId), hash);
        redis.expire(userKey(userId), ttl);
        return token;
    }

    /** Token'i tuketir (tek kullanimlik) ve sahibinin id'sini doner; gecersizse null. */
    public Long consume(String token) {
        String hash = Hashing.sha256(token);
        String v = redis.opsForValue().getAndDelete(TOKEN_PREFIX + hash);
        if (v == null) {
            return null;
        }
        Long userId = Long.valueOf(v);
        redis.opsForSet().remove(userKey(userId), hash);
        return userId;
    }

    public void revoke(String token) {
        consume(token);
    }

    /** Kullanicinin tum refresh token'larini siler (sifre degisimi, "tum cihazlardan cik"). */
    public void revokeAll(Long userId) {
        Set<String> hashes = redis.opsForSet().members(userKey(userId));
        if (hashes != null && !hashes.isEmpty()) {
            redis.delete(hashes.stream().map(h -> TOKEN_PREFIX + h).toList());
        }
        redis.delete(userKey(userId));
    }

    private static String userKey(Long userId) {
        return "rtu:" + userId;
    }
}
