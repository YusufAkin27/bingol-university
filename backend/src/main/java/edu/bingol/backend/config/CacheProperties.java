package edu.bingol.backend.config;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.cache.*`: sunucu tarafi okuma onbellegi (bkz. docs/PERFORMANCE.md "Sunucu onbellegi"). Yalniz "herkese ayni
 * cevap" veren uclar onbelleklenir; kullaniciya ozel veri asla.
 *
 * @param enabled          false = onbellek tamamen kapali (acil durum; her istek veritabanina gider)
 * @param stableTtl        SABIT veri (ayarlar, sozlesmeler, SSS, kategoriler): yazmada zaten gecersiz kilinir
 * @param dailyTtl         GUNLUK veri (menu, haber listesi/detayi): senkron/yonetici yazmasinda gecersiz kilinir
 * @param shortTtl         KISA omurlu veri (durum, kategori sayilari)
 * @param l1Ttl            JVM ici (L1) tazelik ust siniri; cok ornekli calismada baska ornegin gecersiz kilmasi en gec bu kadar sonra gorulur
 * @param staleTtl         suresi dolan kaydin, veritabani hatasinda (stale-while-error) sunulabilecegi ek sure
 * @param negativeTtl      "yok" (null) sonucunun onbellek suresi ust siniri
 * @param maxEntryBytes    tek kaydin (JSON) azami boyutu; asani onbellege alinmaz
 * @param l1MaxEntries     L1 azami kayit sayisi (LRU)
 * @param redisEnabled     false = yalniz JVM ici onbellek (L2 Redis kullanilmaz)
 * @param redisRetryAfter  Redis hatasindan sonra L2'nin atlanacagi sure
 * @param loadWait         ayni anahtarin yukleyicisini bekleyen isteklerin azami bekleme suresi
 */
@ConfigurationProperties("app.cache")
public record CacheProperties(@DefaultValue("true") boolean enabled,
                              @DefaultValue("6h") Duration stableTtl,
                              @DefaultValue("20m") Duration dailyTtl,
                              @DefaultValue("5m") Duration shortTtl,
                              @DefaultValue("15s") Duration l1Ttl,
                              @DefaultValue("1h") Duration staleTtl,
                              @DefaultValue("60s") Duration negativeTtl,
                              @DefaultValue("262144") int maxEntryBytes,
                              @DefaultValue("1000") int l1MaxEntries,
                              @DefaultValue("true") boolean redisEnabled,
                              @DefaultValue("10s") Duration redisRetryAfter,
                              @DefaultValue("10s") Duration loadWait) {

    /** Kod ici varsayilanlar (birim testleri ve onbelleksiz kurulum icin). */
    public static CacheProperties defaults() {
        return new CacheProperties(true, Duration.ofHours(6), Duration.ofMinutes(20), Duration.ofMinutes(5),
                Duration.ofSeconds(15), Duration.ofHours(1), Duration.ofSeconds(60), 262_144, 1000, true,
                Duration.ofSeconds(10), Duration.ofSeconds(10));
    }

    public CacheProperties withEnabled(boolean v) {
        return new CacheProperties(v, stableTtl, dailyTtl, shortTtl, l1Ttl, staleTtl, negativeTtl, maxEntryBytes,
                l1MaxEntries, redisEnabled, redisRetryAfter, loadWait);
    }
}
