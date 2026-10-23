package edu.bingol.backend.auth.token;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.config.JwtProperties;

import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

/**
 * Opak refresh token: Redis'te yalnizca SHA-256 ozeti saklanir. Her kullanimda doner (rotation);
 * eski token tek kullanimliktir.
 */
@Service
public class RefreshTokenService {

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
        redis.opsForValue().set(key(token), String.valueOf(userId), ttl);
        return token;
    }

    /** Token'i tuketir (tek kullanimlik) ve sahibinin id'sini doner; gecersizse null. */
    public Long consume(String token) {
        String v = redis.opsForValue().getAndDelete(key(token));
        return v == null ? null : Long.valueOf(v);
    }

    public void revoke(String token) {
        redis.delete(key(token));
    }

    private static String key(String token) {
        return "rt:" + Hashing.sha256(token);
    }
}
