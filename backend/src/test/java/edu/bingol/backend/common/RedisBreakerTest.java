package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import java.time.Duration;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;

/**
 * T-003 + A01#4: devre kesici (kayan pencere, yari-acik tek prob) ve RateLimiter/ActivityTracker entegrasyonu (birim).
 */
class RedisBreakerTest {

    private final AtomicLong now = new AtomicLong(10_000);
    /** Uretim varsayilani: 2 sn icinde 3 hata, 2 sn acik. */
    private final RedisBreaker breaker = new RedisBreaker(2000, 3, 2000, now::get);
    /** Eski davranis: ilk hatada acar (bu kurucu 1 hata esigi). */
    private final RedisBreaker eager = new RedisBreaker(5000, now::get);

    private void failures(RedisBreaker b, int n) {
        for (int i = 0; i < n; i++) {
            b.trip(new RuntimeException("x"));
        }
    }

    @Test
    void singleTimeoutDoesNotOpenTheBreaker() {
        failures(breaker, 1);
        assertFalse(breaker.isOpen());
        failures(breaker, 1);
        assertFalse(breaker.isOpen());
    }

    @Test
    void threeFailuresWithinTheWindowOpenItForTwoSeconds() {
        failures(breaker, 3);
        assertTrue(breaker.isOpen());
        assertEquals(2, breaker.retryAfterSeconds());
        now.addAndGet(1500);
        assertTrue(breaker.isOpen());
        assertEquals(1, breaker.retryAfterSeconds());
    }

    @Test
    void failuresSpreadOutsideTheWindowNeverAccumulate() {
        failures(breaker, 1);
        now.addAndGet(1500);
        failures(breaker, 1);
        now.addAndGet(1500);
        failures(breaker, 1);
        assertFalse(breaker.isOpen(), "her hata onceki pencerenin disinda kaldi");
    }

    @Test
    void halfOpenLetsExactlyOneProbeThroughAndSuccessClosesIt() {
        failures(breaker, 3);
        now.addAndGet(2001);
        assertFalse(breaker.isOpen(), "ilk istek prob olarak gecer");
        assertFalse(breaker.isOpen(), "ayni is parcacigi (ayni istek) bir sonraki adimda da gecer");
        // baska is parcacigi prob sonuclanana dek 503 alir
        boolean[] otherThreadSawOpen = new boolean[1];
        Thread t = new Thread(() -> otherThreadSawOpen[0] = breaker.isOpen());
        t.start();
        join(t);
        assertTrue(otherThreadSawOpen[0], "tek prob: digerleri kapali devre gibi 503");

        breaker.recordSuccess();
        Thread t2 = new Thread(() -> otherThreadSawOpen[0] = breaker.isOpen());
        t2.start();
        join(t2);
        assertFalse(otherThreadSawOpen[0], "prob basarili: devre kapandi");
    }

    @Test
    void failedProbeReopensForAnotherFullOpenPeriod() {
        failures(breaker, 3);
        now.addAndGet(2001);
        assertFalse(breaker.isOpen());
        breaker.trip(new RuntimeException("probe failed"));
        assertTrue(breaker.isOpen());
        assertEquals(2, breaker.retryAfterSeconds());
    }

    @Test
    void probeThatReportsNothingCountsAsSuccessSoTheBreakerCannotStickHalfOpen() {
        failures(breaker, 3);
        now.addAndGet(2001);
        assertFalse(breaker.isOpen()); // bu is parcacigi prob alir, sonucu bildirmez (hata da yok)
        boolean[] seen = new boolean[1];
        Thread early = new Thread(() -> seen[0] = breaker.isOpen());
        early.start();
        join(early);
        assertTrue(seen[0], "prob suresi dolmadan digerleri beklemeli");
        now.addAndGet(2001);
        Thread t = new Thread(() -> seen[0] = breaker.isOpen());
        t.start();
        join(t);
        assertFalse(seen[0], "prob hata bildirmedi: sessizlik basari sayilir, devre kapandi");
        failures(breaker, 1);
        assertFalse(breaker.isOpen(), "kapandi: hata sayaci sifirdan baslar");
    }

    @Test
    void staleSuccessWhileOpenDoesNotCloseTheBreaker() {
        failures(breaker, 3);
        breaker.recordSuccess(); // acikken gelen eski istegin basarisi
        assertTrue(breaker.isOpen());
    }

    @Test
    void inFlightFailuresWhileOpenDoNotExtendTheOpenPeriod() {
        failures(breaker, 3);
        now.addAndGet(1000);
        failures(breaker, 5);
        now.addAndGet(1001);
        assertFalse(breaker.isOpen(), "ilk acilistan 2 sn sonra yari-acik");
    }

    @Test
    void legacyConstructorKeepsOpeningOnTheFirstFailure() {
        eager.trip(new RuntimeException("x"));
        assertTrue(eager.isOpen());
        assertEquals(5, eager.retryAfterSeconds());
        now.addAndGet(2500);
        assertTrue(eager.isOpen());
        assertEquals(3, eager.retryAfterSeconds());
        now.addAndGet(2501);
        assertFalse(eager.isOpen());
    }

    @Test
    void rateLimiterFailsFastWith503WithoutTouchingRedisWhileOpen() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        RateLimiter limiter = new RateLimiter(redis);
        limiter.setBreaker(breaker);
        failures(breaker, 3);

        for (int i = 0; i < 250; i++) {
            RedisUnavailableException e = assertThrows(RedisUnavailableException.class,
                    () -> limiter.check("login:ip:1.2.3.4", 10, Duration.ofMinutes(1)));
            assertEquals(503, e.status().value());
            assertEquals("REDIS_UNAVAILABLE", e.code());
        }
        verifyNoInteractions(redis);
    }

    @Test
    void rateLimiterFailureReturns503ButOnlyTheThirdFailureOpensTheBreaker() {
        ScriptedRedis redis = new ScriptedRedis();
        redis.down = true;
        RateLimiter limiter = new RateLimiter(redis);
        limiter.setBreaker(breaker);

        assertThrows(RedisUnavailableException.class, () -> limiter.check("k:1", 10, Duration.ofMinutes(1)));
        assertFalse(breaker.isOpen(), "tek zaman asimi devreyi acmaz");
        assertThrows(RedisUnavailableException.class, () -> limiter.check("k:1", 10, Duration.ofMinutes(1)));
        assertThrows(RedisUnavailableException.class, () -> limiter.check("k:1", 10, Duration.ofMinutes(1)));
        assertTrue(breaker.isOpen());
        int before = redis.executes.get();
        assertThrows(RedisUnavailableException.class, () -> limiter.check("k:1", 10, Duration.ofMinutes(1)));
        assertEquals(before, redis.executes.get(), "devre acikken Redis'e gidilmedi");
    }

    @Test
    void rateLimiterReportsSuccessSoARecoveredRedisClosesTheHalfOpenBreaker() {
        ScriptedRedis redis = new ScriptedRedis();
        RateLimiter limiter = new RateLimiter(redis);
        limiter.setBreaker(breaker);
        failures(breaker, 3);
        now.addAndGet(2001);

        limiter.check("k:1", 10, Duration.ofMinutes(1)); // prob basarili

        Thread t = new Thread(() -> limiter.check("k:2", 10, Duration.ofMinutes(1)));
        t.start();
        join(t);
        assertEquals(1L, redis.counters.get("rl:k:2"), "devre kapandi: diger is parcaciklari da gecti");
    }

    @Test
    void rateLimitedStillWinsWhenRedisIsHealthy() {
        ScriptedRedis redis = new ScriptedRedis();
        RateLimiter limiter = new RateLimiter(redis);
        limiter.setBreaker(breaker);
        for (int i = 0; i < 10; i++) {
            limiter.check("k:9", 10, Duration.ofMinutes(1));
        }
        assertThrows(RateLimitedException.class, () -> limiter.check("k:9", 10, Duration.ofMinutes(1)));
        assertFalse(breaker.isOpen());
    }

    @Test
    void activityTrackerSkipsRedisWhileOpen() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        edu.bingol.backend.analytics.ActivityTracker tracker = new edu.bingol.backend.analytics.ActivityTracker(redis,
                mock(edu.bingol.backend.analytics.ActivityRepository.class), java.time.Clock.systemUTC());
        org.springframework.test.util.ReflectionTestUtils.setField(tracker, "breaker", breaker);
        failures(breaker, 3);

        tracker.touch(5L);

        verify(redis, never()).opsForValue();
    }

    private static void join(Thread t) {
        try {
            t.join(2000);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
