package edu.bingol.backend.common.cache;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/** Birim testleri icin bellek ici sahte Redis (TTL yok sayilir; "down" acikken her islem hata verir). */
final class FakeRedis {

    final Map<String, String> data = new ConcurrentHashMap<>();
    final AtomicBoolean down = new AtomicBoolean();
    final StringRedisTemplate template = mock(StringRedisTemplate.class);

    @SuppressWarnings("unchecked")
    FakeRedis() {
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(template.opsForValue()).thenAnswer(inv -> {
            check();
            return ops;
        });
        when(ops.get(anyString())).thenAnswer(inv -> {
            check();
            return data.get(inv.<String>getArgument(0));
        });
        org.mockito.Mockito.doAnswer(inv -> {
            check();
            data.put(inv.getArgument(0), inv.getArgument(1));
            return null;
        }).when(ops).set(anyString(), anyString(), any(Duration.class));
        when(ops.increment(anyString())).thenAnswer(inv -> {
            check();
            return Long.valueOf(data.merge(inv.<String>getArgument(0), "1",
                    (a, b) -> String.valueOf(Long.parseLong(a) + 1)));
        });
        when(template.expire(anyString(), any(Duration.class))).thenReturn(true);
    }

    private void check() {
        if (down.get()) {
            throw new org.springframework.data.redis.RedisConnectionFailureException("down");
        }
    }

    long keysWithPrefix(String prefix) {
        return data.keySet().stream().filter(k -> k.startsWith(prefix)).count();
    }
}
