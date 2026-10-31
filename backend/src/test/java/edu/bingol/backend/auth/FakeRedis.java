package edu.bingol.backend.auth;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Duration;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import org.springframework.data.redis.core.SetOperations;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

/**
 * Bellek ici Redis taklidi (birim testleri icin): yalniz auth testlerinin kullandigi komutlar. TTL izlenmez
 * (set edilen sure {@link #ttls}'e yazilir, dolma simule edilmez).
 */
public class FakeRedis {

    public final Map<String, String> values = new HashMap<>();
    public final Map<String, Set<String>> sets = new HashMap<>();
    public final Map<String, Duration> ttls = new HashMap<>();
    public final StringRedisTemplate template = mock(StringRedisTemplate.class);

    @SuppressWarnings("unchecked")
    public FakeRedis() {
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        SetOperations<String, String> setOps = mock(SetOperations.class);
        when(template.opsForValue()).thenReturn(ops);
        when(template.opsForSet()).thenReturn(setOps);

        when(ops.get(anyString())).thenAnswer(i -> values.get(i.<String>getArgument(0)));
        org.mockito.Mockito.doAnswer(i -> {
            values.put(i.getArgument(0), i.getArgument(1));
            ttls.put(i.getArgument(0), i.getArgument(2));
            return null;
        }).when(ops).set(anyString(), anyString(), any(Duration.class));
        org.mockito.Mockito.doAnswer(i -> {
            values.put(i.getArgument(0), i.getArgument(1));
            return null;
        }).when(ops).set(anyString(), anyString());
        when(ops.setIfAbsent(anyString(), anyString(), any(Duration.class))).thenAnswer(i -> {
            String k = i.getArgument(0);
            if (values.containsKey(k)) {
                return false;
            }
            values.put(k, i.getArgument(1));
            return true;
        });
        when(ops.increment(anyString())).thenAnswer(i -> {
            String k = i.getArgument(0);
            long n = Long.parseLong(values.getOrDefault(k, "0")) + 1;
            values.put(k, String.valueOf(n));
            return n;
        });
        when(ops.getAndDelete(anyString())).thenAnswer(i -> values.remove(i.<String>getArgument(0)));
        when(ops.multiGet(anyCollection())).thenAnswer(i -> {
            Collection<String> keys = i.getArgument(0);
            return keys.stream().map(values::get).collect(java.util.stream.Collectors.toList());
        });

        when(setOps.add(anyString(), org.mockito.ArgumentMatchers.<String[]>any())).thenAnswer(i -> {
            Set<String> set = sets.computeIfAbsent(i.getArgument(0), k -> new HashSet<>());
            long added = 0;
            Object[] args = i.getRawArguments();
            Object[] vals = (Object[]) args[1];
            for (Object v : vals) {
                if (set.add((String) v)) {
                    added++;
                }
            }
            return added;
        });
        when(setOps.members(anyString())).thenAnswer(i -> {
            Set<String> s = sets.get(i.<String>getArgument(0));
            return s == null ? Set.of() : new HashSet<>(s);
        });
        when(setOps.remove(anyString(), any())).thenAnswer(i -> {
            Set<String> s = sets.get(i.<String>getArgument(0));
            return s != null && s.remove((String) i.getArgument(1)) ? 1L : 0L;
        });

        when(template.hasKey(anyString())).thenAnswer(i -> {
            String k = i.getArgument(0);
            return values.containsKey(k) || sets.containsKey(k);
        });
        when(template.delete(anyString())).thenAnswer(i -> {
            String k = i.getArgument(0);
            boolean had = values.remove(k) != null;
            had |= sets.remove(k) != null;
            return had;
        });
        when(template.delete(anyCollection())).thenAnswer(i -> {
            Collection<String> keys = i.getArgument(0);
            long n = 0;
            for (String k : keys) {
                if (values.remove(k) != null | sets.remove(k) != null) {
                    n++;
                }
            }
            return n;
        });
        when(template.expire(anyString(), any(Duration.class))).thenReturn(true);
        when(template.getExpire(anyString())).thenReturn(600L);
    }
}
