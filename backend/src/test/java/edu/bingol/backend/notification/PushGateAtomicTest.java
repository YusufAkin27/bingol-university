package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.RedisScript;

/** P04 (A04#14): sayac artirma ve TTL TEK Redis betigindedir; INCR ile EXPIRE arasinda kopan baglanti TTL'siz anahtar birakmaz. */
class PushGateAtomicTest {

    @Test
    void incrAndExpireRunInOneScriptNotTwoRoundTrips() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        when(redis.execute(any(RedisScript.class), anyList(), any(Object[].class))).thenReturn(1L);

        long n = PushGate.redisStore(redis).incr("pushcap:7", Duration.ofMinutes(1));

        assertEquals(1L, n);
        verify(redis).execute(eq(PushGate.INCR_WITH_TTL), eq(List.of("pushcap:7")), eq("60000"));
        verify(redis, never()).expire(anyString(), any(Duration.class));
        verify(redis, never()).opsForValue();
    }

    @Test
    void scriptIncrementsAndSetsExpiryWhenKeyHasNoTtl() {
        String lua = PushGate.INCR_WITH_TTL.getScriptAsString();
        assertTrue(lua.contains("INCR"));
        // TTL'siz kalmis (eski/yarim kalmis) anahtar da kendini onarir: PTTL < 0 ise yeniden EXPIRE
        assertTrue(lua.contains("PTTL") && lua.contains("PEXPIRE"));
    }

    @Test
    void failureOfRedisFailsOpenSoPushStillGoes() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        when(redis.execute(any(RedisScript.class), anyList(), any(Object[].class)))
                .thenThrow(new org.springframework.data.redis.RedisConnectionFailureException("down"));
        PushGate gate = new PushGate(PushGate.redisStore(redis), 0, 10);

        assertTrue(gate.allowGeneralPush(1L)); // Redis yoksa acik (eski davranis korunur)
    }
}
