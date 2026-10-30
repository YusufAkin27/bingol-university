package edu.bingol.backend.common.cache;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.CacheProperties;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

/** Sunucu onbellegi cekirdegi: hit/miss, L2, gecersiz kilma, tek ucus, stale-while-error, kapatma, anahtar korumasi. */
class CacheServiceTest {

    record Item(Long id, String name, List<String> tags) {}

    static final TypeReference<Item> ITEM = new TypeReference<>() { };
    static final TypeReference<List<Item>> ITEMS = new TypeReference<>() { };
    static final JsonMapper JSON = JsonMapper.builder().build();

    static CacheProperties props(Duration daily, Duration l1, Duration stale) {
        return new CacheProperties(true, Duration.ofHours(6), daily, Duration.ofMinutes(5), l1, stale,
                Duration.ofSeconds(60), 262_144, 1000, true, Duration.ofSeconds(10), Duration.ofSeconds(5));
    }

    static CacheService service(CacheProperties p, FakeRedis redis) {
        return new CacheService(p, JSON, redis == null ? null : redis.template, null);
    }

    static final CacheProperties DEFAULT = props(Duration.ofMinutes(20), Duration.ofSeconds(15), Duration.ofHours(1));

    private static Item load(AtomicInteger calls) {
        calls.incrementAndGet();
        return new Item(1L, "a", List.of("x", "y"));
    }

    @Test
    void missThenHitServesFromCacheWithoutLoader() {
        CacheService c = service(DEFAULT, new FakeRedis());
        AtomicInteger calls = new AtomicInteger();
        Item first = c.get("news", "k1", CacheTier.DAILY, ITEM, () -> load(calls));
        Item second = c.get("news", "k1", CacheTier.DAILY, ITEM, () -> load(calls));
        assertEquals(1, calls.get());
        assertEquals(first, second);
        assertEquals(1, c.stat("news", "miss"));
        assertEquals(1, c.stat("news", "hit_l1"));
    }

    @Test
    void secondInstanceReadsJsonFromRedisL2() {
        FakeRedis redis = new FakeRedis();
        CacheService a = service(DEFAULT, redis);
        CacheService b = service(DEFAULT, redis);
        AtomicInteger calls = new AtomicInteger();
        Item loaded = a.get("menu", "m:2026-10", CacheTier.DAILY, ITEM, () -> load(calls));
        Item viaL2 = b.get("menu", "m:2026-10", CacheTier.DAILY, ITEM, () -> load(calls));
        assertEquals(1, calls.get(), "ikinci ornek Redis'ten okumali");
        assertEquals(loaded, viaL2, "JSON gidis-donus kayipsiz olmali");
        assertEquals(1, b.stat("menu", "hit_l2"));
        assertTrue(redis.keysWithPrefix("cache:menu:0:") >= 1, "anahtar bicimi cache:<ad>:<surum>:<anahtar>");
    }

    @Test
    void listsRoundTripThroughRedis() {
        FakeRedis redis = new FakeRedis();
        List<Item> src = List.of(new Item(1L, "a", List.of()), new Item(2L, "b", List.of("t")));
        service(DEFAULT, redis).get("faq", "l:tr", CacheTier.STABLE, ITEMS, () -> src);
        List<Item> got = service(DEFAULT, redis).get("faq", "l:tr", CacheTier.STABLE, ITEMS, () -> null);
        assertEquals(src, got);
    }

    @Test
    void invalidateForcesReload() {
        CacheService c = service(DEFAULT, new FakeRedis());
        AtomicInteger calls = new AtomicInteger();
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        c.invalidate("news");
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        assertEquals(2, calls.get());
    }

    @Test
    void invalidateOnlyAffectsItsNamespace() {
        CacheService c = service(DEFAULT, new FakeRedis());
        AtomicInteger calls = new AtomicInteger();
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        c.get("menu", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        c.invalidate("news");
        c.get("menu", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        assertEquals(2, calls.get());
    }

    @Test
    void invalidationReachesOtherInstanceThroughRedisVersion() {
        FakeRedis redis = new FakeRedis();
        // l1Ttl = 0: ikinci ornek her seferinde Redis surumune bakar
        CacheProperties noL1 = props(Duration.ofMinutes(20), Duration.ZERO, Duration.ofHours(1));
        CacheService a = service(noL1, redis);
        CacheService b = service(noL1, redis);
        AtomicInteger calls = new AtomicInteger();
        b.get("legal", "k", CacheTier.STABLE, ITEM, () -> load(calls));
        a.invalidate("legal");
        b.get("legal", "k", CacheTier.STABLE, ITEM, () -> load(calls));
        assertEquals(2, calls.get(), "diger ornegin gecersiz kilmasi Redis surumuyle gorulmeli");
    }

    @Test
    void languageKeysAreIndependent() {
        CacheService c = service(DEFAULT, new FakeRedis());
        Item tr = c.get("faq", "l:tr", CacheTier.STABLE, ITEM, () -> new Item(1L, "soru", List.of()));
        Item en = c.get("faq", "l:en", CacheTier.STABLE, ITEM, () -> new Item(1L, "question", List.of()));
        assertEquals("soru", tr.name());
        assertEquals("question", en.name());
        assertEquals("soru", c.get("faq", "l:tr", CacheTier.STABLE, ITEM, () -> null).name());
    }

    @Test
    void singleFlightRunsLoaderOnce() throws Exception {
        CacheService c = service(DEFAULT, new FakeRedis());
        AtomicInteger calls = new AtomicInteger();
        int n = 12;
        ExecutorService pool = Executors.newFixedThreadPool(n);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<Item>> fs = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            fs.add(pool.submit(() -> {
                go.await();
                return c.get("news", "hot", CacheTier.DAILY, ITEM, () -> {
                    calls.incrementAndGet();
                    try {
                        Thread.sleep(300);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                    return new Item(7L, "hot", List.of());
                });
            }));
        }
        go.countDown();
        for (Future<Item> f : fs) {
            assertEquals("hot", f.get().name());
        }
        pool.shutdownNow();
        assertEquals(1, calls.get(), "ayni anahtar icin tek yukleyici");
    }

    @Test
    void servesStaleWhenLoaderFailsWithServerError() throws Exception {
        // daily TTL 30 ms, l1 10 ms: hizla bayatlar; stale penceresi 1 sa
        CacheService c = service(props(Duration.ofMillis(30), Duration.ofMillis(10), Duration.ofHours(1)), new FakeRedis());
        c.get("menu", "k", CacheTier.DAILY, ITEM, () -> new Item(1L, "eski", List.of()));
        Thread.sleep(80);
        Item got = c.get("menu", "k", CacheTier.DAILY, ITEM, () -> {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "DB_TIMEOUT", "db");
        });
        assertEquals("eski", got.name());
        assertEquals(1, c.stat("menu", "stale"));
        Item got2 = c.get("menu", "k", CacheTier.DAILY, ITEM, () -> {
            throw new IllegalStateException("db down");
        });
        assertEquals("eski", got2.name(), "genel RuntimeException da bayat kayitla karsilanir");
    }

    @Test
    void clientErrorIsNeverMaskedByStale() throws Exception {
        CacheService c = service(props(Duration.ofMillis(30), Duration.ofMillis(10), Duration.ofHours(1)), new FakeRedis());
        c.get("menu", "k", CacheTier.DAILY, ITEM, () -> new Item(1L, "eski", List.of()));
        Thread.sleep(80);
        assertThrows(ApiException.class, () -> c.get("menu", "k", CacheTier.DAILY, ITEM, () -> {
            throw new ApiException(HttpStatus.NOT_FOUND, "X", "yok");
        }));
    }

    @Test
    void staleIsNotServedAfterInvalidation() throws Exception {
        CacheService c = service(props(Duration.ofMillis(30), Duration.ofMillis(10), Duration.ofHours(1)), new FakeRedis());
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> new Item(1L, "gizlenecek", List.of()));
        c.invalidate("news");
        Thread.sleep(80);
        assertThrows(IllegalStateException.class, () -> c.get("news", "k", CacheTier.DAILY, ITEM, () -> {
            throw new IllegalStateException("db down");
        }), "gecersiz kilinmis (ornegin gizlenmis) veri hata aninda bile sunulmamali");
    }

    @Test
    void staleSurvivesOnlyWithinStaleWindow() throws Exception {
        CacheService c = service(props(Duration.ofMillis(20), Duration.ofMillis(10), Duration.ofMillis(40)), new FakeRedis());
        c.get("menu", "k", CacheTier.DAILY, ITEM, () -> new Item(1L, "eski", List.of()));
        Thread.sleep(150);
        assertThrows(IllegalStateException.class, () -> c.get("menu", "k", CacheTier.DAILY, ITEM, () -> {
            throw new IllegalStateException("db down");
        }));
    }

    @Test
    void disabledCacheAlwaysCallsLoader() {
        CacheService c = service(DEFAULT.withEnabled(false), new FakeRedis());
        AtomicInteger calls = new AtomicInteger();
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        assertEquals(2, calls.get());
        AtomicInteger p = new AtomicInteger();
        CacheService.passthrough().get("news", "k", CacheTier.DAILY, ITEM, () -> load(p));
        CacheService.passthrough().get("news", "k", CacheTier.DAILY, ITEM, () -> load(p));
        assertEquals(2, p.get());
    }

    @Test
    void unsafeKeysBypassTheCache() {
        FakeRedis redis = new FakeRedis();
        CacheService c = service(DEFAULT, redis);
        AtomicInteger calls = new AtomicInteger();
        String evil = "q:x\r\nSET evil 1";
        c.get("news", evil, CacheTier.DAILY, ITEM, () -> load(calls));
        c.get("news", evil, CacheTier.DAILY, ITEM, () -> load(calls));
        c.get("news", "k".repeat(200), CacheTier.DAILY, ITEM, () -> load(calls));
        c.get("Bad NS", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        assertEquals(4, calls.get());
        assertTrue(redis.data.isEmpty(), "beyaz liste disi anahtar Redis'e yazilmamali");
    }

    @Test
    void nullIsCachedByGetButNotByGetPositive() {
        CacheService c = service(DEFAULT, new FakeRedis());
        AtomicInteger calls = new AtomicInteger();
        assertNull(c.get("menu", "today", CacheTier.DAILY, ITEM, () -> {
            calls.incrementAndGet();
            return null;
        }));
        assertNull(c.get("menu", "today", CacheTier.DAILY, ITEM, () -> {
            calls.incrementAndGet();
            return null;
        }));
        assertEquals(1, calls.get(), "olumsuz sonuc kisa sure onbelleklenir");
        AtomicInteger p = new AtomicInteger();
        for (int i = 0; i < 3; i++) {
            c.getPositive("news", "d:99", CacheTier.DAILY, ITEM, () -> {
                p.incrementAndGet();
                return null;
            });
        }
        assertEquals(3, p.get(), "bulunamayan kayit (kullanici girdisi anahtar) onbelleklenmemeli");
    }

    @Test
    void oversizedEntriesAreNotCached() {
        CacheProperties tiny = new CacheProperties(true, Duration.ofHours(6), Duration.ofMinutes(20), Duration.ofMinutes(5),
                Duration.ofSeconds(15), Duration.ofHours(1), Duration.ofSeconds(60), 64, 1000, true,
                Duration.ofSeconds(10), Duration.ofSeconds(5));
        FakeRedis redis = new FakeRedis();
        CacheService c = service(tiny, redis);
        AtomicInteger calls = new AtomicInteger();
        for (int i = 0; i < 2; i++) {
            c.get("news", "big", CacheTier.DAILY, ITEM, () -> {
                calls.incrementAndGet();
                return new Item(1L, "x".repeat(500), List.of());
            });
        }
        assertEquals(2, calls.get());
        assertEquals(2, c.stat("news", "oversize"));
        assertTrue(redis.data.keySet().stream().noneMatch(k -> k.startsWith("cache:news:0:")));
    }

    @Test
    void redisFailureDegradesToLoaderAndL1() {
        FakeRedis redis = new FakeRedis();
        redis.down.set(true);
        CacheService c = service(DEFAULT, redis);
        AtomicInteger calls = new AtomicInteger();
        Item a = c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        Item b = c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        assertEquals(1, calls.get(), "Redis olmadan da L1 calismali");
        assertEquals(a, b);
        c.invalidate("news");
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        assertEquals(2, calls.get());
    }

    @Test
    void l1HitReturnsSameInstanceAndRespectsMaxEntries() {
        CacheProperties small = new CacheProperties(true, Duration.ofHours(6), Duration.ofMinutes(20), Duration.ofMinutes(5),
                Duration.ofSeconds(15), Duration.ofHours(1), Duration.ofSeconds(60), 262_144, 10, false,
                Duration.ofSeconds(10), Duration.ofSeconds(5));
        CacheService c = service(small, null);
        Item x = c.get("news", "k0", CacheTier.DAILY, ITEM, () -> new Item(0L, "k0", List.of()));
        assertSame(x, c.get("news", "k0", CacheTier.DAILY, ITEM, () -> null));
        AtomicInteger calls = new AtomicInteger();
        for (int i = 1; i <= 30; i++) {
            long id = i;
            c.get("news", "k" + i, CacheTier.DAILY, ITEM, () -> new Item(id, "n", List.of()));
        }
        c.get("news", "k0", CacheTier.DAILY, ITEM, () -> load(calls));
        assertEquals(1, calls.get(), "LRU siniri asilinca eski kayit dusmeli");
    }

    @Test
    void invalidateInsideTransactionRunsOnlyAfterCommit() {
        CacheService c = service(DEFAULT, new FakeRedis());
        AtomicInteger calls = new AtomicInteger();
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        TransactionSynchronizationManager.initSynchronization();
        TransactionSynchronizationManager.setActualTransactionActive(true);
        try {
            c.invalidate("news");
            c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
            assertEquals(1, calls.get(), "commit'ten once kayit hala gecerli (okuyucu eski veriyi yeniden doldurmasin)");
            for (TransactionSynchronization s : TransactionSynchronizationManager.getSynchronizations()) {
                s.afterCommit();
            }
        } finally {
            TransactionSynchronizationManager.setActualTransactionActive(false);
            TransactionSynchronizationManager.clear();
        }
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        assertEquals(2, calls.get(), "commit sonrasi gecersiz kilinmali");
    }

    @Test
    void invalidateInsideRolledBackTransactionDoesNothing() {
        CacheService c = service(DEFAULT, new FakeRedis());
        AtomicInteger calls = new AtomicInteger();
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        TransactionSynchronizationManager.initSynchronization();
        TransactionSynchronizationManager.setActualTransactionActive(true);
        try {
            c.invalidate("news");
            // afterCommit calistirilmaz (geri alma)
        } finally {
            TransactionSynchronizationManager.setActualTransactionActive(false);
            TransactionSynchronizationManager.clear();
        }
        c.get("news", "k", CacheTier.DAILY, ITEM, () -> load(calls));
        assertEquals(1, calls.get());
    }

    @Test
    void invalidationDuringLoadDoesNotLeaveStaleEntry() throws Exception {
        CacheService c = service(DEFAULT, new FakeRedis());
        CountDownLatch inLoader = new CountDownLatch(1);
        CountDownLatch proceed = new CountDownLatch(1);
        ExecutorService pool = Executors.newSingleThreadExecutor();
        Future<Item> f = pool.submit(() -> c.get("news", "k", CacheTier.DAILY, ITEM, () -> {
            inLoader.countDown();
            try {
                proceed.await();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            return new Item(1L, "eski", List.of());
        }));
        inLoader.await();
        c.invalidate("news");
        proceed.countDown();
        assertEquals("eski", f.get().name());
        pool.shutdownNow();
        Item fresh = c.get("news", "k", CacheTier.DAILY, ITEM, () -> new Item(1L, "yeni", List.of()));
        assertEquals("yeni", fresh.name(), "yukleme sirasinda gecersiz kilinan kayit onbellege girmemeli");
    }
}
