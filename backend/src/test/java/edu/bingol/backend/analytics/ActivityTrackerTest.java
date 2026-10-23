package edu.bingol.backend.analytics;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

class ActivityTrackerTest {

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final ActivityRepository repo = mock(ActivityRepository.class);
    // 23 Ekim 21:30 UTC = 24 Ekim 00:30 Istanbul: gun, Istanbul takvimine gore 24
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-23T21:30:00Z"), ZoneOffset.UTC);
    private final ActivityTracker tracker = new ActivityTracker(redis, repo, clock);

    ActivityTrackerTest() {
        when(redis.opsForValue()).thenReturn(ops);
    }

    @Test
    void throttledRequestsDoNotTouchTheDatabase() throws Exception {
        when(ops.setIfAbsent(eq("seen:7"), anyString(), any(Duration.class))).thenReturn(false);

        tracker.touch(7L);
        Thread.sleep(100);

        verify(repo, never()).touchLastSeen(any());
        verify(repo, never()).markActive(any(), any());
    }

    @Test
    void firstRequestWritesLastSeenAndTodayInIstanbul() {
        when(ops.setIfAbsent(eq("seen:7"), anyString(), any(Duration.class))).thenReturn(true);
        when(ops.setIfAbsent(eq("act:7:2026-10-24"), anyString(), any(Duration.class))).thenReturn(true);

        tracker.touch(7L);

        verify(repo, timeout(2000)).touchLastSeen(7L);
        verify(repo, timeout(2000)).markActive(7L, LocalDate.parse("2026-10-24"));
    }

    @Test
    void laterRequestSameDayUpdatesOnlyLastSeen() {
        when(ops.setIfAbsent(eq("seen:7"), anyString(), any(Duration.class))).thenReturn(true);
        when(ops.setIfAbsent(eq("act:7:2026-10-24"), anyString(), any(Duration.class))).thenReturn(false);

        tracker.touch(7L);

        verify(repo, timeout(2000)).touchLastSeen(7L);
        verify(repo, never()).markActive(any(), any());
    }

    @Test
    void redisFailureIsSwallowed() {
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenThrow(new RuntimeException("redis down"));

        tracker.touch(7L); // exception sizmamali

        verify(repo, never()).touchLastSeen(any());
    }
}
