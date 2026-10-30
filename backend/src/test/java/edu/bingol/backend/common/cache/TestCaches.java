package edu.bingol.backend.common.cache;

import edu.bingol.backend.config.CacheProperties;
import tools.jackson.databind.json.JsonMapper;

/** Diger paketlerin birim testleri icin: sahte Redis'li, gercek JSON serilestirmeli onbellek. */
public final class TestCaches {

    private TestCaches() {}

    /** Her cagri yeni bir sahte Redis ile bagimsiz bir onbellek ornegi uretir. */
    public static CacheService create() {
        return new CacheService(CacheProperties.defaults(), JsonMapper.builder().build(), new FakeRedis().template, null);
    }

    /** Iki ornek ayni Redis'i paylasir (L2 davranisi; baska ornegin kaydini JSON'dan okur). */
    public static CacheService[] pair() {
        FakeRedis redis = new FakeRedis();
        JsonMapper json = JsonMapper.builder().build();
        return new CacheService[] {
            new CacheService(CacheProperties.defaults(), json, redis.template, null),
            new CacheService(CacheProperties.defaults(), json, redis.template, null)
        };
    }
}
