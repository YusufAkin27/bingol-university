package edu.bingol.backend.common.cache;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.bingol.backend.config.CacheProperties;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

/** T-075 (A2-15): Redis kesintisinde kacan gecersiz kilma, Redis donunce telafi edilir (eski L2 surumu geri gelmez). */
class CacheInvalidateCompensationTest {

    private static final CacheProperties PROPS = new CacheProperties(true, Duration.ofHours(6), Duration.ofMinutes(20),
            Duration.ofMinutes(5), Duration.ofSeconds(15), Duration.ofHours(1), Duration.ofSeconds(60), 262_144, 1000,
            true, Duration.ofMillis(30), Duration.ofSeconds(5));

    private static String load(AtomicInteger calls) {
        return "v" + calls.incrementAndGet();
    }

    @Test
    void invalidationMissedDuringRedisOutageIsCompensatedOnRecovery() throws Exception {
        FakeRedis redis = new FakeRedis();
        CacheService c = CacheServiceTest.service(PROPS, redis);
        AtomicInteger calls = new AtomicInteger();
        assertEquals("v1", c.get("news", "k", CacheTier.DAILY, new tools.jackson.core.type.TypeReference<String>() { },
                () -> load(calls)));

        redis.down.set(true);
        c.invalidateNow("news"); // Redis'e yazilamaz: yalniz L1 + yerel surum
        assertEquals(1, c.pendingInvalidationCount());

        redis.down.set(false);
        Thread.sleep(80); // redisRetryAfter penceresi gecsin
        String after = c.get("news", "k", CacheTier.DAILY, new tools.jackson.core.type.TypeReference<String>() { },
                () -> load(calls));

        assertEquals("v2", after, "eski L2 surumunun kaydi geri gelmemeli");
        assertEquals(0, c.pendingInvalidationCount());
        assertEquals(1, c.stat("news", "invalidate_compensated"));
    }

    @Test
    void invalidationInsideRetryWindowIsAlsoRemembered() {
        FakeRedis redis = new FakeRedis();
        CacheService c = CacheServiceTest.service(CacheServiceTest.props(Duration.ofMinutes(20), Duration.ofSeconds(15),
                Duration.ofHours(1)), redis);
        redis.down.set(true);
        c.get("menu", "k", CacheTier.DAILY, new tools.jackson.core.type.TypeReference<List<String>>() { },
                () -> List.of("a")); // Redis hatasi -> geri atlama penceresi acilir
        c.invalidateNow("menu");     // pencere acik: Redis'e hic gidilmez, ama isaretlenmeli
        assertEquals(1, c.pendingInvalidationCount());
    }
}
