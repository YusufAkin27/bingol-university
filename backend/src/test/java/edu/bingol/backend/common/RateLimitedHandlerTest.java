package edu.bingol.backend.common;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.i18n.I18n;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

class RateLimitedHandlerTest {

    @Test
    @SuppressWarnings("unchecked")
    void limiterThrowsWithRemainingTtlAndHandlerSetsRetryAfter() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.increment(anyString())).thenReturn(4L);
        when(redis.getExpire(anyString())).thenReturn(42L);
        RateLimitedException e = assertThrows(RateLimitedException.class,
                () -> new RateLimiter(redis).check("k", 3, Duration.ofMinutes(1)));
        assertEquals(42, e.retryAfterSeconds());

        I18n i18n = mock(I18n.class);
        when(i18n.error(anyString(), anyString(), any(), any())).thenReturn("cok fazla");
        var res = new ApiExceptionHandler(i18n).rateLimited(e);
        assertEquals(429, res.getStatusCode().value());
        assertEquals("42", res.getHeaders().getFirst("Retry-After"));
        assertEquals("RATE_LIMITED", res.getBody().get("code"));
    }
}
