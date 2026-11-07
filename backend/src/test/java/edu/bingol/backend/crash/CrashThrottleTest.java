package edu.bingol.backend.crash;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.RedisScript;

/** FIX-P09 (A08#1): imza freni esigi, Redis hatasinda fail-open ve tasma alani bicimi. */
class CrashThrottleTest {

    @Test
    @SuppressWarnings("unchecked")
    void allowsUpToTheLimitThenDenies() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        when(redis.execute(any(RedisScript.class), anyList(), any(Object[].class))).thenReturn(1L, 29L, 30L, 31L);
        CrashThrottle t = new CrashThrottle(redis, 30);
        Instant now = Instant.parse("2026-11-01T10:00:00Z");
        assertThat(t.allow("sig", now)).isTrue();
        assertThat(t.allow("sig", now)).isTrue();
        assertThat(t.allow("sig", now)).isTrue();
        assertThat(t.allow("sig", now)).isFalse();
    }

    @Test
    @SuppressWarnings("unchecked")
    void failsOpenWhenRedisIsDown() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        when(redis.execute(any(RedisScript.class), anyList(), any(Object[].class)))
                .thenThrow(new RuntimeException("redis down"));
        assertThat(new CrashThrottle(redis, 30).allow("sig", Instant.now())).isTrue();
    }

    @Test
    void overflowFieldRoundTrips() {
        String f = CrashThrottle.field("abc", "2.0.5+3", "ANDROID");
        assertThat(CrashThrottle.parse(f)).containsExactly("abc", "2.0.5+3", "ANDROID");
        assertThat(CrashThrottle.parse("bozuk")).isNull();
    }
}
