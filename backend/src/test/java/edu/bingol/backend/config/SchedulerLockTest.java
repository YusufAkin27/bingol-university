package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.core.script.RedisScript;

@SuppressWarnings("unchecked")
class SchedulerLockTest {

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final SchedulerLock lock = new SchedulerLock(redis);

    SchedulerLockTest() {
        when(redis.opsForValue()).thenReturn(ops);
    }

    @Test
    void runsTaskAndReleasesWhenLockAcquired() {
        when(ops.setIfAbsent(eq("schedlock:job"), anyString(), any(Duration.class))).thenReturn(true);
        AtomicInteger n = new AtomicInteger();
        assertTrue(lock.tryRun("job", Duration.ofMinutes(1), n::incrementAndGet));
        assertEquals(1, n.get());
        verify(redis).execute(any(RedisScript.class), anyList(), anyString());
    }

    @Test
    void skipsTaskWhenAnotherInstanceHoldsLock() {
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenReturn(false);
        AtomicInteger n = new AtomicInteger();
        assertFalse(lock.tryRun("job", Duration.ofMinutes(1), n::incrementAndGet));
        assertEquals(0, n.get());
    }

    @Test
    void skipsTaskWhenRedisFails() {
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenThrow(new IllegalStateException("down"));
        AtomicInteger n = new AtomicInteger();
        assertFalse(lock.tryRun("job", Duration.ofMinutes(1), n::incrementAndGet));
        assertEquals(0, n.get());
    }
}
