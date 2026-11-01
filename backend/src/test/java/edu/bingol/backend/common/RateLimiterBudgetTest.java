package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * A01#1 / A10#17: yeni-anahtar butcesi ONEK basina sayilir, dogrulanmis kullanici anahtarlari (son parca rakam) butceden
 * muaftir, INCR+EXPIRE tek betiktir (TTL'siz anahtar kalmaz).
 */
class RateLimiterBudgetTest {

    private final ScriptedRedis redis = new ScriptedRedis();
    private final RateLimiter limiter = new RateLimiter(redis);

    private void budget(long perPrefix, long global, int multiplier) {
        ReflectionTestUtils.setField(limiter, "newKeyBudgetPerPrefix", perPrefix);
        ReflectionTestUtils.setField(limiter, "newKeyBudget", global);
        ReflectionTestUtils.setField(limiter, "overflowMultiplier", multiplier);
    }

    @Test
    void userKeysAreNotCollapsedIntoTheSharedBucketWhenBudgetIsExhausted() {
        budget(2, 1000, 50);
        // kimliksiz (e-posta ozeti) anahtarlar butceyi doldurur
        for (int i = 0; i < 4; i++) {
            limiter.check("acd:read:hash" + i, 100, Duration.ofHours(1));
        }
        assertTrue(redis.counters.containsKey("rl:ovf:acd"), "kimliksiz anahtarlar ortak kovaya duser");

        // dogrulanmis kullanici anahtari kendi kovasinda ve KENDI limitiyle sayilir
        limiter.check("acd:read:123", 3, Duration.ofHours(1));
        limiter.check("acd:read:123", 3, Duration.ofHours(1));
        limiter.check("acd:read:123", 3, Duration.ofHours(1));
        assertEquals(3L, redis.counters.get("rl:acd:read:123"));
        assertThrows(RateLimitedException.class, () -> limiter.check("acd:read:123", 3, Duration.ofHours(1)));
    }

    @Test
    void anonymousEmailHashKeyStillFallsIntoOverflowBucketOverBudget() {
        budget(1, 1000, 50);
        limiter.check("register:email:aaaa1111", 5, Duration.ofHours(1));
        limiter.check("register:email:bbbb2222", 5, Duration.ofHours(1));
        assertFalse(redis.counters.containsKey("rl:register:email:bbbb2222"), "butce asildi: ayri anahtar yok");
        assertEquals(1L, redis.counters.get("rl:ovf:register"));
    }

    @Test
    void budgetIsCountedPerPrefixSoOneNoisyPrefixDoesNotStarveOthers() {
        budget(2, 1000, 50);
        for (int i = 0; i < 10; i++) {
            limiter.check("login:email:h" + i, 100, Duration.ofHours(1));
        }
        assertTrue(redis.counters.containsKey("rl:ovf:login"));
        // baska onek hala kendi yeni anahtarini alir
        limiter.check("forgot:email:hx", 5, Duration.ofHours(1));
        assertTrue(redis.counters.containsKey("rl:forgot:email:hx"));
        assertFalse(redis.counters.containsKey("rl:ovf:forgot"));
    }

    @Test
    void globalBackstopStillBoundsRedisMemoryAcrossPrefixes() {
        budget(100, 3, 50);
        for (int i = 0; i < 6; i++) {
            limiter.check("p" + i + ":ip:x" + i, 100, Duration.ofHours(1));
        }
        long perKey = redis.counters.keySet().stream().filter(k -> k.startsWith("rl:p")).count();
        assertEquals(3, perKey, "genel tavan korunur");
    }

    @Test
    void ipv6LikeKeysAreNeverTreatedAsUserKeys() {
        assertTrue(RateLimiter.isUserKey("acd:read:123"));
        assertTrue(RateLimiter.isUserKey("viewing:55:123"));
        assertFalse(RateLimiter.isUserKey("login:ip:v6:2001:0db8:0001:0002::/64"));
        assertFalse(RateLimiter.isUserKey("login:ip:2001:db8::5"));
        assertFalse(RateLimiter.isUserKey("login:ip:2001:db8:0:0:0:0:0:5"));
        assertFalse(RateLimiter.isUserKey("login:ip:1.2.3.4"));
        assertFalse(RateLimiter.isUserKey("register:email:abcdef"));
        assertFalse(RateLimiter.isUserKey("acd:read:" + "9".repeat(19)));
        assertFalse(RateLimiter.isUserKey("123"));
        assertFalse(RateLimiter.isUserKey("acd:read:"));
        assertFalse(RateLimiter.isUserKey(null));
    }

    @Test
    void ipv6KeyCollapsesWhenOverBudgetEvenIfLastSegmentIsADigit() {
        budget(1, 1000, 50);
        limiter.check("login:ip:2001:db8::5", 5, Duration.ofHours(1));
        limiter.check("login:ip:2001:db8::6", 5, Duration.ofHours(1));
        assertFalse(redis.counters.containsKey("rl:login:ip:2001:db8::6"));
        assertTrue(redis.counters.containsKey("rl:ovf:login"));
    }

    @Test
    void existingKeyCostsExactlyOneRedisRoundTripAndNoSeparateExpire() {
        budget(100, 1000, 50);
        limiter.check("conv:pref:7", 100, Duration.ofMinutes(1));
        int afterFirst = redis.executes.get();
        limiter.check("conv:pref:7", 100, Duration.ofMinutes(1));
        assertEquals(1, redis.executes.get() - afterFirst, "INCR+EXPIRE tek betik: istek basina tek tur");
        assertEquals(60_000L, redis.ttlMs.get("rl:conv:pref:7"), "TTL betik icinde konur");
    }

    @Test
    void windowShorterThanOneSecondStillGetsATtl() {
        limiter.check("fast:7", 100, Duration.ofMillis(300));
        assertEquals(300L, redis.ttlMs.get("rl:fast:7"));
    }

    @Test
    void overflowIncrementsMetricAndNoticesOncePerPrefix() {
        budget(1, 1000, 50);
        SimpleMeterRegistry meters = new SimpleMeterRegistry();
        limiter.setMeterRegistry(meters);
        limiter.check("login:email:a", 100, Duration.ofHours(1));
        limiter.check("login:email:b", 100, Duration.ofHours(1));
        limiter.check("login:email:c", 100, Duration.ofHours(1));
        assertEquals(2.0, meters.counter("bu.ratelimit.overflow", "prefix", "login").count());
        assertNull(meters.find("bu.ratelimit.overflow").tag("prefix", "forgot").counter());
    }

    @Test
    void budgetOfZeroOrLessKeepsLegacyMeaningOfNoBudget() {
        budget(0, 0, 50);
        for (int i = 0; i < 20; i++) {
            limiter.check("login:email:h" + i, 100, Duration.ofHours(1));
        }
        assertFalse(redis.counters.containsKey("rl:ovf:login"));
    }
}
