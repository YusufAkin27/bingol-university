package edu.bingol.backend.auth.token;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.token.PendingRegistrationStore.Pending;
import edu.bingol.backend.config.AuthProperties;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Range;
import org.springframework.data.redis.connection.Limit;
import org.springframework.data.redis.core.HashOperations;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.core.ZSetOperations;

/**
 * FIX-P02/A01#8 (A08#2): kayit yazimi eski alanlari BIRLESTIRMEZ; yonetici listesi Redis SCAN yapmaz (dizin).
 * Bellek ici Redis taklidi: hash, zset (sozluk sirasi), rename, delete.
 */
class PendingRegistrationStoreTest {

    private final Map<String, Map<Object, Object>> hashes = new HashMap<>();
    private final Map<String, TreeMap<String, Double>> zsets = new HashMap<>();
    private final Map<String, String> strings = new HashMap<>();
    private int scanCalls;
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    private final PendingRegistrationStore store;

    @SuppressWarnings("unchecked")
    PendingRegistrationStoreTest() {
        HashOperations<String, Object, Object> hops = mock(HashOperations.class);
        ZSetOperations<String, String> zops = mock(ZSetOperations.class);
        ValueOperations<String, String> vops = mock(ValueOperations.class);
        when(redis.opsForHash()).thenReturn((HashOperations) hops);
        when(redis.opsForZSet()).thenReturn(zops);
        when(redis.opsForValue()).thenReturn(vops);
        org.mockito.Mockito.doAnswer(i -> {
            hashes.computeIfAbsent(i.getArgument(0), k -> new HashMap<>()).putAll((Map<Object, Object>) i.getArgument(1));
            return null;
        }).when(hops).putAll(anyString(), any(Map.class));
        when(hops.entries(anyString())).thenAnswer(i -> new HashMap<>(hashes.getOrDefault(i.<String>getArgument(0), Map.of())));
        when(redis.delete(anyString())).thenAnswer(i -> hashes.remove(i.<String>getArgument(0)) != null);
        org.mockito.Mockito.doAnswer(i -> {
            Map<Object, Object> m = hashes.remove(i.<String>getArgument(0));
            if (m == null) {
                throw new IllegalStateException("no such key");
            }
            hashes.put(i.getArgument(1), m);
            return null;
        }).when(redis).rename(anyString(), anyString());
        when(redis.expire(anyString(), any(Duration.class))).thenReturn(true);
        when(redis.getExpire(anyString())).thenReturn(1000L);
        when(redis.hasKey(anyString())).thenAnswer(i -> strings.containsKey(i.<String>getArgument(0))
                || hashes.containsKey(i.<String>getArgument(0)));
        org.mockito.Mockito.doAnswer(i -> {
            strings.put(i.getArgument(0), i.getArgument(1));
            return null;
        }).when(vops).set(anyString(), anyString());
        when(redis.scan(any())).thenAnswer(i -> {
            scanCalls++;
            return mock(org.springframework.data.redis.core.Cursor.class);
        });

        when(zops.add(anyString(), anyString(), anyDouble())).thenAnswer(i -> {
            zsets.computeIfAbsent(i.getArgument(0), k -> new TreeMap<>()).put(i.getArgument(1), i.getArgument(2));
            return true;
        });
        when(zops.remove(anyString(), any(Object[].class))).thenAnswer(i -> {
            TreeMap<String, Double> z = zsets.get(i.<String>getArgument(0));
            Object[] vals = (Object[]) i.getRawArguments()[1];
            long n = 0;
            for (Object v : vals) {
                n += z != null && z.remove((String) v) != null ? 1 : 0;
            }
            return n;
        });
        when(zops.rangeByLex(anyString(), any(Range.class), any(Limit.class))).thenAnswer(i -> {
            TreeMap<String, Double> z = zsets.getOrDefault(i.<String>getArgument(0), new TreeMap<>());
            Range<String> r = i.getArgument(1);
            Limit lim = i.getArgument(2);
            return z.keySet().stream()
                    .filter(k -> r.getLowerBound().getValue().map(lo -> r.getLowerBound().isInclusive()
                            ? k.compareTo(lo) >= 0 : k.compareTo(lo) > 0).orElse(true))
                    .limit(lim.getCount()).collect(Collectors.toCollection(java.util.LinkedHashSet::new));
        });
        when(zops.rangeByScore(anyString(), anyDouble(), anyDouble(), anyLong(), anyLong())).thenAnswer(i -> {
            TreeMap<String, Double> z = zsets.getOrDefault(i.<String>getArgument(0), new TreeMap<>());
            double max = i.getArgument(2);
            return z.entrySet().stream().filter(e -> e.getValue() <= max).map(Map.Entry::getKey)
                    .limit((long) i.getArgument(4)).collect(Collectors.toCollection(java.util.LinkedHashSet::new));
        });
        store = new PendingRegistrationStore(redis, new AuthProperties(Duration.ofHours(72), 90, Duration.ofHours(1),
                Duration.ofSeconds(10)));
        strings.put(PendingRegistrationStore.IDX_READY, "1"); // dizin kurulu: SCAN yok
    }

    @Test
    void secondSaveDoesNotKeepFacultyDepartmentGradeOfTheFirst() {
        store.save("a@bingol.edu.tr", new Pending("h1", "Ali", "tr", "Muh", "Bilgisayar", "2"));

        store.save("a@bingol.edu.tr", new Pending("h2", "Ali", "tr")); // fakulte/bolum/sinif verilmedi

        Pending p = store.find("a@bingol.edu.tr");
        assertEquals("h2", p.passwordHash());
        assertNull(p.faculty(), "eski fa alani birakilmamali");
        assertNull(p.department());
        assertNull(p.grade());
    }

    @Test
    void listIsEmailSortedPagedByCursorAndNeverScansRedis() {
        for (String e : List.of("c@bingol.edu.tr", "a@bingol.edu.tr", "b@bingol.edu.tr")) {
            store.save(e, new Pending("h", "N " + e, "tr"));
        }

        PendingRegistrationStore.EntryPage p1 = store.list(null, 2);
        assertEquals(List.of("a@bingol.edu.tr", "b@bingol.edu.tr"),
                p1.items().stream().map(PendingRegistrationStore.Entry::email).toList());
        assertEquals("b@bingol.edu.tr", p1.nextCursor());
        PendingRegistrationStore.EntryPage p2 = store.list(p1.nextCursor(), 2);
        assertEquals(List.of("c@bingol.edu.tr"), p2.items().stream().map(PendingRegistrationStore.Entry::email).toList());
        assertNull(p2.nextCursor());
        assertEquals(0, scanCalls, "Redis SCAN yapilmamali");
    }

    @Test
    void queryFilterAndRemovalKeepTheIndexConsistent() {
        store.save("ali@bingol.edu.tr", new Pending("h", "Ali Veli", "tr"));
        store.save("ayse@bingol.edu.tr", new Pending("h", "Ayse", "tr"));

        assertEquals(1, store.list(null, 10, "veli").items().size());
        store.remove("ali@bingol.edu.tr");
        store.delete("ayse@bingol.edu.tr");

        assertTrue(store.list(null, 10).items().isEmpty());
        assertTrue(zsets.getOrDefault(PendingRegistrationStore.IDX, new TreeMap<>()).isEmpty());
    }

    @Test
    void entryWhoseKeyExpiredIsDroppedFromTheIndexOnList() {
        store.save("gone@bingol.edu.tr", new Pending("h", "Gone", "tr"));
        hashes.remove("reg:gone@bingol.edu.tr"); // Redis TTL ile anahtari sildi, dizin hala tutuyor

        assertTrue(store.list(null, 10).items().isEmpty());
        assertTrue(zsets.get(PendingRegistrationStore.IDX).isEmpty());
    }

    @Test
    void missingIndexIsBuiltOnceFromExistingKeysAndThenNeverScansAgain() {
        strings.remove(PendingRegistrationStore.IDX_READY);

        store.list(null, 10);
        store.list(null, 10);

        assertEquals(1, scanCalls, "yalniz ilk listelemede tek kurulum taramasi");
        assertTrue(strings.containsKey(PendingRegistrationStore.IDX_READY));
    }
}
