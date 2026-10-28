package edu.bingol.backend.auth;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.RateLimitedException;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/** Giris kilidi: yalniz basarisiz denemeler, (e-posta, istemci) cifti basina; baskasi hesabi kilitleyemez. */
class LoginThrottleTest {

    private static final String EMAIL = "ali@bingol.edu.tr";

    private final Map<String, Long> counters = new HashMap<>();
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final LoginThrottle throttle = new LoginThrottle(redis);

    LoginThrottleTest() {
        when(redis.opsForValue()).thenReturn(ops);
        when(ops.get(anyString())).thenAnswer(i -> {
            Long v = counters.get(i.<String>getArgument(0));
            return v == null ? null : String.valueOf(v);
        });
        when(ops.increment(anyString())).thenAnswer(i -> counters.merge(i.<String>getArgument(0), 1L, Long::sum));
        when(redis.getExpire(anyString())).thenReturn(600L);
        when(redis.delete(anyString())).thenAnswer(i -> counters.remove(i.<String>getArgument(0)) != null);
    }

    @Test
    void attackerFailuresLockOnlyTheAttackersOwnClient() {
        for (int i = 0; i < LoginThrottle.PAIR_MAX; i++) {
            throttle.check(EMAIL, "6.6.6.6");
            throttle.recordFailure(EMAIL, "6.6.6.6");
        }

        RateLimitedException e = assertThrows(RateLimitedException.class, () -> throttle.check(EMAIL, "6.6.6.6"));
        assertEquals(600L, e.retryAfterSeconds());
        // gercek kullanici baska istemciden hala girebilir (hedefli kilitleme DoS yok)
        assertDoesNotThrow(() -> throttle.check(EMAIL, "198.51.100.7"));
    }

    @Test
    void successfulLoginResetsThePairCounter() {
        for (int i = 0; i < LoginThrottle.PAIR_MAX - 1; i++) {
            throttle.recordFailure(EMAIL, "198.51.100.7");
        }
        throttle.recordSuccess(EMAIL, "198.51.100.7");

        for (int i = 0; i < LoginThrottle.PAIR_MAX - 1; i++) {
            throttle.recordFailure(EMAIL, "198.51.100.7");
        }
        assertDoesNotThrow(() -> throttle.check(EMAIL, "198.51.100.7"));
    }

    @Test
    void distributedBruteForceHitsPerEmailCeilingForEveryClient() {
        for (int i = 0; i < LoginThrottle.EMAIL_MAX; i++) {
            throttle.recordFailure(EMAIL, "10.1." + (i / 200) + "." + (i % 200)); // her seferinde farkli istemci
        }

        assertThrows(RateLimitedException.class, () -> throttle.check(EMAIL, "198.51.100.200"));
    }

    @Test
    void plusAliasesShareTheSameCounterAndKeysAreFixedLength() {
        for (int i = 0; i < LoginThrottle.PAIR_MAX; i++) {
            throttle.recordFailure("ali+" + i + "@bingol.edu.tr", "6.6.6.6");
        }

        assertThrows(RateLimitedException.class, () -> throttle.check(EMAIL, "6.6.6.6"));
        counters.keySet().forEach(k -> assertTrue(k.length() < 80, k));
        verify(ops, atLeastOnce()).increment(startsWith("lgf:"));
    }
}
