package edu.bingol.backend.common.cache;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.appinfo.AppSetting;
import edu.bingol.backend.appinfo.AppSettingRepository;
import edu.bingol.backend.support.faq.FaqItem;
import edu.bingol.backend.support.faq.FaqRepository;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/**
 * P07-B10: gercek JPA islemlerinde (persist anindaki ve commit-flush anindaki varlik olaylari) ad alani islem basina
 * bir kez, commit SONRASI gecersiz kilinir; ardisik islemler birbirinin kumesini devralmaz.
 */
@SpringBootTest(properties = "app.cache.e2e=true")
class CacheInvalidateRealTxTest {

    @Autowired CacheService cache;
    @Autowired FaqRepository faq;
    @Autowired AppSettingRepository settings;
    @MockitoBean StringRedisTemplate redis;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        ValueOperations<String, String> ops = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(ops);
    }

    private FaqItem item() {
        FaqItem f = new FaqItem();
        f.setLang("tr");
        f.setCategory("TX");
        f.setQuestion("soru-" + UUID.randomUUID());
        f.setAnswer("cevap");
        return f;
    }

    @Test
    void persistAndRemoveEachInvalidateOnceAfterCommit() {
        long before = cache.stat("faq", "invalidate");
        FaqItem f = faq.save(item());
        assertEquals(before + 1, cache.stat("faq", "invalidate"), "persist: commit sonrasi bir kez");

        faq.delete(f);
        assertEquals(before + 2, cache.stat("faq", "invalidate"), "remove (commit-flush aninda olay): bir kez");

        faq.save(item());
        assertEquals(before + 3, cache.stat("faq", "invalidate"), "onceki islemin kumesi devralinmaz");
    }

    @Test
    void updateOfExistingRowInvalidatesAfterCommit() {
        AppSetting s = settings.findById("maintenance_mode").orElseGet(() -> {
            AppSetting n = new AppSetting();
            n.setKey("maintenance_mode");
            n.setValue("false");
            return n;
        });
        s.setValue("false");
        settings.save(s);
        long before = cache.stat("appinfo", "invalidate");
        s.setValue("true");
        settings.save(s);
        assertEquals(before + 1, cache.stat("appinfo", "invalidate"));
        s.setValue("false");
        settings.save(s);
        assertEquals(before + 2, cache.stat("appinfo", "invalidate"));
    }
}
