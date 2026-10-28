package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.test.util.ReflectionTestUtils;

/** Redis anahtar guvenligi: uzun girdi ozetlenir, her anahtarin TTL'i vardir, yeni anahtar butcesi bellegi korur. */
class RateLimiterKeySafetyTest {

    /** Sayac + TTL tutan basit sahte Redis. */
    private static final class FakeRedis {
        final Map<String, Long> counters = new HashMap<>();
        final Map<String, Duration> ttl = new HashMap<>();
        final StringRedisTemplate template = mock(StringRedisTemplate.class);

        @SuppressWarnings("unchecked")
        FakeRedis() {
            ValueOperations<String, String> ops = mock(ValueOperations.class);
            when(template.opsForValue()).thenReturn(ops);
            when(ops.increment(anyString())).thenAnswer(i -> counters.merge(i.getArgument(0), 1L, Long::sum));
            when(template.expire(anyString(), any(Duration.class))).thenAnswer(i -> {
                ttl.put(i.getArgument(0), i.getArgument(1));
                return true;
            });
            when(template.getExpire(anyString())).thenAnswer(i -> {
                Duration d = ttl.get((String) i.getArgument(0));
                return d == null ? -1L : d.toSeconds();
            });
            when(template.delete(anyString())).thenAnswer(i -> {
                counters.remove((String) i.getArgument(0));
                ttl.remove((String) i.getArgument(0));
                return true;
            });
        }
    }

    @Test
    void longRawInputIsHashedToFixedSizeKeyAndRawValueNeverReachesRedis() {
        FakeRedis r = new FakeRedis();
        RateLimiter limiter = new RateLimiter(r.template);
        String email = "x".repeat(250) + "@bingol.edu.tr";

        limiter.check("login:email:" + email, 10, Duration.ofMinutes(15));

        String stored = r.counters.keySet().stream().filter(k -> k.startsWith("rl:")).findFirst().orElseThrow();
        assertTrue(stored.length() <= 3 + 32 + 1 + 32, "anahtar sabit boyutta: " + stored.length());
        assertFalse(stored.contains("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"));
        // Ayni girdi ayni anahtar: sayac ilerler
        limiter.check("login:email:" + email, 10, Duration.ofMinutes(15));
        assertEquals(2L, r.counters.get(stored));
        // Farkli (uzun) girdi farkli anahtar
        limiter.check("login:email:" + email + "y", 10, Duration.ofMinutes(15));
        assertEquals(1L, r.counters.keySet().stream().filter(k -> k.startsWith("rl:login")).count() - 1);
    }

    @Test
    void shortKeysAreKeptAsIsAndLongOnesAreDeterministic() {
        assertEquals("login:ip:1.2.3.4", RateLimiter.safeKey("login:ip:1.2.3.4"));
        String a = RateLimiter.safeKey("a".repeat(200));
        assertEquals(a, RateLimiter.safeKey("a".repeat(200)));
        assertNotEquals(a, RateLimiter.safeKey("a".repeat(199) + "b"));
        assertTrue(a.length() < 80);
    }

    @Test
    void everyNewKeyGetsATtl() {
        FakeRedis r = new FakeRedis();
        RateLimiter limiter = new RateLimiter(r.template);
        for (int i = 0; i < 20; i++) {
            limiter.check("forgot:email:u" + i + "@bingol.edu.tr", 5, Duration.ofHours(1));
        }
        for (String k : r.counters.keySet()) {
            assertTrue(r.ttl.containsKey(k), "TTL yok: " + k);
        }
    }

    @Test
    void overBudgetKeysCollapseIntoSharedOverflowBucketInsteadOfGrowingRedis() {
        FakeRedis r = new FakeRedis();
        RateLimiter limiter = new RateLimiter(r.template);
        ReflectionTestUtils.setField(limiter, "newKeyBudget", 5L);
        ReflectionTestUtils.setField(limiter, "overflowMultiplier", 2);

        for (int i = 0; i < 9; i++) { // 5 yeni anahtar + 4 tasma (ortak limit 3 x 2 = 6 icinde)
            limiter.check("login:email:attacker" + i + "@bingol.edu.tr", 3, Duration.ofMinutes(15));
        }

        long perKey = r.counters.keySet().stream().filter(k -> k.startsWith("rl:login:email:")).count();
        assertEquals(5, perKey, "butce kadar yeni anahtar");
        assertTrue(r.counters.containsKey("rl:ovf:login"), "tasma kovasi");
        assertTrue(r.ttl.containsKey("rl:ovf:login"));
    }

    @Test
    void overflowBucketStillRateLimitsWithLooserSharedLimit() {
        FakeRedis r = new FakeRedis();
        RateLimiter limiter = new RateLimiter(r.template);
        ReflectionTestUtils.setField(limiter, "newKeyBudget", 1L);
        ReflectionTestUtils.setField(limiter, "overflowMultiplier", 2);
        limiter.check("k:a", 3, Duration.ofMinutes(1)); // butceyi bitirir (1. yeni anahtar)
        // max 3 x 2 = 6 -> 6 istek gecer, 7.'si 429
        for (int i = 0; i < 6; i++) {
            limiter.check("k:new" + i, 3, Duration.ofMinutes(1));
        }
        assertThrows(RateLimitedException.class, () -> limiter.check("k:another", 3, Duration.ofMinutes(1)));
    }

    @Test
    void normalLimitStillWorks() {
        FakeRedis r = new FakeRedis();
        RateLimiter limiter = new RateLimiter(r.template);
        for (int i = 0; i < 3; i++) {
            limiter.check("x:1", 3, Duration.ofMinutes(1));
        }
        assertThrows(RateLimitedException.class, () -> limiter.check("x:1", 3, Duration.ofMinutes(1)));
    }
}
