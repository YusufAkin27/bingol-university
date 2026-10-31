package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Duration;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/** T-003: devre kesici ve RateLimiter/ActivityTracker entegrasyonu (birim). */
class RedisBreakerTest {

    private final AtomicLong now = new AtomicLong(10_000);
    private final RedisBreaker breaker = new RedisBreaker(5000, now::get);

    @Test
    void opensOnTripAndClosesAfterTheWindowWithRetryAfterCountdown() {
        assertFalse(breaker.isOpen());
        breaker.trip(new RuntimeException("x"));
        assertTrue(breaker.isOpen());
        assertEquals(5, breaker.retryAfterSeconds());
        now.addAndGet(2500);
        assertTrue(breaker.isOpen());
        assertEquals(3, breaker.retryAfterSeconds());
        now.addAndGet(2501);
        assertFalse(breaker.isOpen());
    }

    @Test
    void rateLimiterFailsFastWith503WithoutTouchingRedisWhileOpen() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        RateLimiter limiter = new RateLimiter(redis);
        limiter.setBreaker(breaker);
        breaker.trip(new RuntimeException("x"));

        for (int i = 0; i < 250; i++) {
            RedisUnavailableException e = assertThrows(RedisUnavailableException.class,
                    () -> limiter.check("login:ip:1.2.3.4", 10, Duration.ofMinutes(1)));
            assertEquals(503, e.status().value());
            assertEquals("REDIS_UNAVAILABLE", e.code());
        }
        verify(redis, never()).opsForValue();
    }

    @Test
    void rateLimiterTripsTheBreakerOnTheFirstRedisFailureAndKeepsBusinessErrors() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        @SuppressWarnings("unchecked")
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.increment(anyString())).thenThrow(new RedisConnectionFailureException("down"));
        RateLimiter limiter = new RateLimiter(redis);
        limiter.setBreaker(breaker);

        assertThrows(RedisUnavailableException.class, () -> limiter.check("k", 10, Duration.ofMinutes(1)));
        assertTrue(breaker.isOpen());
        assertThrows(RedisUnavailableException.class, () -> limiter.check("k", 10, Duration.ofMinutes(1)));
        // devre acikken ikinci cagri Redis'e gitmedi: increment tek kez denendi
        verify(ops, times(1)).increment(anyString());
    }

    @Test
    void rateLimitedStillWinsWhenRedisIsHealthy() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        @SuppressWarnings("unchecked")
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.increment(anyString())).thenReturn(11L);
        when(redis.getExpire(anyString())).thenReturn(30L);
        RateLimiter limiter = new RateLimiter(redis);
        limiter.setBreaker(breaker);

        assertThrows(RateLimitedException.class, () -> limiter.check("k", 10, Duration.ofMinutes(1)));
        assertFalse(breaker.isOpen());
    }

    @Test
    void activityTrackerSkipsRedisWhileOpen() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        edu.bingol.backend.analytics.ActivityTracker tracker = new edu.bingol.backend.analytics.ActivityTracker(redis,
                mock(edu.bingol.backend.analytics.ActivityRepository.class), java.time.Clock.systemUTC());
        org.springframework.test.util.ReflectionTestUtils.setField(tracker, "breaker", breaker);
        breaker.trip(new RuntimeException("x"));

        tracker.touch(5L);

        verify(redis, never()).opsForValue();
    }
}
