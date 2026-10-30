package edu.bingol.backend.common.cache;

import jakarta.persistence.PostPersist;
import jakarta.persistence.PostRemove;
import jakarta.persistence.PostUpdate;
import java.util.Map;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * JPA entity dinleyicisi: onbelleklenen okuma verisinin kaynagi olan varliklarda her ekleme/guncelleme/silme ilgili
 * onbellek ad alanini gecersiz kilar. Yazma yolu hangisi olursa olsun (yonetici ucu, senkron isi, toplu islem) kacmaz;
 * gecersiz kilma COMMIT'ten sonra calisir ({@link CacheService#invalidate}). JPQL/SQL toplu guncellemeler (@Modifying,
 * JdbcTemplate) varlik olayi uretmez: bunlar ilgili serviste elle {@code invalidate} cagirmalidir.
 *
 * <p>Hibernate dinleyiciyi Spring ile olusturur; onbellek bean'i yoksa (dilim testleri) alan bos kalir ve hicbir sey yapilmaz.
 * Yeni onbelleklenen veri = varlik sinifini ve ad alanini buraya ekleyin ve varliga {@code @EntityListeners} koyun.
 */
public class CacheInvalidationListener {

    /** Varlik basit adi -> gecersiz kilinacak ad alanlari. */
    static final Map<String, String[]> NAMESPACES = Map.of(
            "NewsItem", new String[] {"news"},
            "MenuDay", new String[] {"menu"},
            "MenuItemCalorie", new String[] {"menu"},
            "SyncStatus", new String[] {"status"},
            "AppSetting", new String[] {"appinfo"},
            "LegalDocument", new String[] {"legal"},
            "FaqItem", new String[] {"faq"},
            "CommunityCategory", new String[] {"categories"},
            // kategori sayilari (kesfette gorunen kulup) Community durumuna baglidir
            "Community", new String[] {"categories"});

    /** Tembel cozulur: EntityManagerFactory kurulurken CacheService'e dairesel bagimlilik olusmasin. */
    @Autowired(required = false)
    private ObjectProvider<CacheService> cacheProvider;

    @PostPersist
    @PostUpdate
    @PostRemove
    void changed(Object entity) {
        if (cacheProvider == null || entity == null) {
            return;
        }
        String name = entity.getClass().getSimpleName();
        int dollar = name.indexOf('$');
        String[] ns = NAMESPACES.get(dollar > 0 ? name.substring(0, dollar) : name);
        if (ns != null) {
            CacheService cache = cacheProvider.getIfAvailable();
            if (cache != null) {
                cache.invalidate(ns);
            }
        }
    }
}
