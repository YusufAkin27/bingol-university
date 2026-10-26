package edu.bingol.backend.common;

import java.time.Duration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/** Redis tabanli sabit pencere (fixed window) rate limit. Birden fazla sunucuda da ortak calisir. */
@Component
public class RateLimiter {

    private final StringRedisTemplate redis;

    public RateLimiter(StringRedisTemplate redis) {
        this.redis = redis;
    }

    /** `key` icin pencere icinde `max` istegi asarsa 429 firlatir. */
    public void check(String key, int max, Duration window) {
        String k = "rl:" + key;
        Long n = redis.opsForValue().increment(k);
        if (n == null) {
            return;
        }
        if (n == 1 || redis.getExpire(k) < 0) {
            redis.expire(k, window);
        }
        if (n > max) {
            Long ttl = redis.getExpire(k);
            throw new RateLimitedException(ttl == null || ttl < 0 ? window.toSeconds() : ttl);
        }
    }
}
