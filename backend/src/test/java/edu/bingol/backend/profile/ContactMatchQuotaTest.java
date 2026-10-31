package edu.bingol.backend.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.RateLimitedException;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/** T-061: gunluk toplam aday tavani (hesap basina 2000). */
class ContactMatchQuotaTest {

    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    private final ContactMatchQuota quota = new ContactMatchQuota(redis, 2000);

    ContactMatchQuotaTest() {
        when(redis.opsForValue()).thenReturn(ops);
    }

    @Test
    void firstBatchSetsTtlAndPasses() {
        when(ops.increment(anyString(), eq(500L))).thenReturn(500L);

        quota.consume(7L, 500);

        verify(redis).expire(anyString(), eq(Duration.ofHours(30)));
    }

    @Test
    void exactlyAtCapPasses() {
        when(ops.increment(anyString(), eq(500L))).thenReturn(2000L);

        quota.consume(7L, 500);

        verify(ops, never()).decrement(anyString(), eq(500L));
    }

    @Test
    void overCapIsRejectedWithRetryAfterAndRolledBack() {
        when(ops.increment(anyString(), eq(500L))).thenReturn(2100L);
        when(redis.getExpire(anyString())).thenReturn(7200L);

        RateLimitedException e = assertThrows(RateLimitedException.class, () -> quota.consume(7L, 500));

        assertEquals(429, e.status().value());
        assertEquals(7200L, e.retryAfterSeconds());
        verify(ops).decrement(anyString(), eq(500L)); // asan istek sayilmaz
    }

    @Test
    void capDefaultsAreSane() {
        assertEquals(2000, quota.cap());
        assertEquals(1, new ContactMatchQuota(redis, 0).cap());
    }
}
