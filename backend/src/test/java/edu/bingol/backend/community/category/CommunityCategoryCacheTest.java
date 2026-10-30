package edu.bingol.backend.community.category;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.TestCaches;
import edu.bingol.backend.community.CommunityRepository;
import java.time.Instant;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.context.i18n.LocaleContextHolder;

/** Kulup kategorileri: dil anahtarli kisa omurlu onbellek; surum basligi icin tum tablo taramasi tekrarlanmaz. */
class CommunityCategoryCacheTest {

    private final CommunityCategoryRepository repo = mock(CommunityCategoryRepository.class);
    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final CacheService cache = TestCaches.create();
    private final CommunityCategoryService service = new CommunityCategoryService(repo, communities);

    private static CommunityCategory cat(String key, String tr, String en) {
        CommunityCategory c = new CommunityCategory();
        c.setKey(key);
        c.setNameTr(tr);
        c.setNameEn(en);
        c.setNameAr(tr);
        c.setActive(true);
        c.setUpdatedAt(Instant.parse("2026-10-01T00:00:00Z"));
        return c;
    }

    @BeforeEach
    void wire() {
        service.setCache(cache);
        when(repo.findByActiveTrueOrderBySortOrderAscIdAsc()).thenReturn(List.of(cat("spor", "Spor", "Sports")));
        when(communities.categoryCounts(any(), any())).thenReturn(Collections.singletonList(new Object[] {"spor", 4L}));
        when(repo.findAll()).thenReturn(List.of(cat("spor", "Spor", "Sports")));
        when(repo.count()).thenReturn(1L);
    }

    @AfterEach
    void reset() {
        LocaleContextHolder.resetLocaleContext();
    }

    @Test
    void listIsCachedPerLanguage() {
        LocaleContextHolder.setLocale(Locale.forLanguageTag("tr"));
        assertEquals("Spor", service.listActive().get(0).name());
        service.listActive();
        LocaleContextHolder.setLocale(Locale.forLanguageTag("en"));
        assertEquals("Sports", service.listActive().get(0).name());
        assertEquals(4L, service.listActive().get(0).count());
        verify(repo, times(2)).findByActiveTrueOrderBySortOrderAscIdAsc();
    }

    @Test
    void versionIsCachedAndRefreshedOnInvalidate() {
        String v1 = service.version();
        service.version();
        verify(repo, times(1)).findAll();
        cache.invalidate("categories");
        assertEquals(v1, service.version());
        verify(repo, times(2)).findAll();
    }
}
