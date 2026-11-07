package edu.bingol.backend.common;

import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.RedisScript;

/**
 * RateLimiter testleri icin sahte Redis: Lua betiklerinin (INCR+TTL, yeni anahtar butcesi) anlamini Java'da taklit eder.
 * {@code opsForValue()} bilerek mock'lanmaz: RateLimiter sayaci ayrik INCR/EXPIRE ile yazarsa NPE verir.
 */
final class ScriptedRedis extends StringRedisTemplate {

    final Map<String, Long> counters = new HashMap<>();
    final Map<String, Long> ttlMs = new HashMap<>();
    final AtomicInteger executes = new AtomicInteger();
    /** true iken her komut baglanti hatasi verir. */
    volatile boolean down;
    /** Dolu iken her komut bu istisnayi firlatir (down'dan once). */
    volatile RuntimeException failure;

    private void guard() {
        if (failure != null) {
            throw failure;
        }
        if (down) {
            throw new RedisConnectionFailureException("down");
        }
    }

    @Override
    @SuppressWarnings("unchecked")
    public <T> T execute(RedisScript<T> script, List<String> keys, Object... args) {
        guard();
        executes.incrementAndGet();
        if (script == RateLimiter.INCR_TTL) {
            return (T) (Long) incrTtl(keys.get(0), Long.parseLong(String.valueOf(args[0])));
        }
        if (script == RateLimiter.NEW_KEY_BUDGET) {
            long ttl = Long.parseLong(String.valueOf(args[0]));
            long prefixLimit = Long.parseLong(String.valueOf(args[1]));
            long globalLimit = Long.parseLong(String.valueOf(args[2]));
            long p = incrTtl(keys.get(0), ttl);
            if (prefixLimit > 0 && p > prefixLimit) {
                return (T) (Long) 1L;
            }
            long g = incrTtl(keys.get(1), ttl);
            return (T) (Long) (globalLimit > 0 && g > globalLimit ? 1L : 0L);
        }
        // SchedulerLock vb. baska betikler: sorun degil
        return (T) (Long) 1L;
    }

    private long incrTtl(String key, long windowMs) {
        long n = counters.merge(key, 1L, Long::sum);
        Long cur = ttlMs.get(key);
        if (n == 1 || cur == null || cur < 0) {
            ttlMs.put(key, windowMs);
        }
        return n;
    }

    @Override
    public Boolean delete(String key) {
        guard();
        ttlMs.remove(key);
        return counters.remove(key) != null;
    }

    @Override
    public Long getExpire(String key) {
        guard();
        Long ms = ttlMs.get(key);
        return ms == null ? -1L : Duration.ofMillis(ms).toSeconds();
    }

    @Override
    public Boolean expire(String key, Duration timeout) {
        guard();
        ttlMs.put(key, timeout.toMillis());
        return true;
    }
}
