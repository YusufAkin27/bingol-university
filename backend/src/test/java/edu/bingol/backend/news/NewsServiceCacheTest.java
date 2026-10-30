package edu.bingol.backend.news;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.cache.CacheService;
import edu.bingol.backend.common.cache.TestCaches;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

/** Haber listesi/detayi sunucu onbellegi: ayni cevap onbellekten, arama/derin sayfa/yok sonucu onbelleksiz. */
class NewsServiceCacheTest {

    private final NewsRepository repo = mock(NewsRepository.class);
    private final CacheService cache = TestCaches.create();
    private final NewsService service = new NewsService(repo);

    private static NewsItem item(long id, String title) {
        NewsItem n = new NewsItem();
        n.setId(id);
        n.setType(ContentType.HABER);
        n.setUrl("https://www.bingol.edu.tr/" + id);
        n.setTitle(title);
        n.setSummary("ozet");
        n.setContent("icerik");
        n.setPublishedDate(LocalDate.of(2026, 10, 1));
        return n;
    }

    @BeforeEach
    void wire() {
        service.setCache(cache);
        when(repo.findByHiddenFalse(any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(item(1, "Baslik")), PageRequest.of(0, 20), 1));
        when(repo.findByTypeAndHiddenFalse(any(ContentType.class), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(item(2, "Tur")), PageRequest.of(0, 20), 1));
    }

    @Test
    void sameListIsServedFromCacheAfterFirstLoad() {
        var a = service.list(null, null, 0, 20);
        var b = service.list(null, "  ", 0, 20);
        verify(repo, times(1)).findByHiddenFalse(any(Pageable.class));
        assertEquals(a, b);
        assertEquals("Baslik", b.items().get(0).title());
    }

    @Test
    void listKeyedByTypePageAndSize() {
        service.list(null, null, 0, 20);
        service.list(ContentType.HABER, null, 0, 20);
        service.list(ContentType.HABER, null, 0, 20);
        service.list(null, null, 0, 10);
        verify(repo, times(2)).findByHiddenFalse(any(Pageable.class));
        verify(repo, times(1)).findByTypeAndHiddenFalse(any(ContentType.class), any(Pageable.class));
    }

    @Test
    void searchAndDeepPagesAreNeverCached() {
        when(repo.searchPage(any(), anyString(), anyString(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(), PageRequest.of(0, 20), 0));
        service.list(null, "kampus", 0, 20);
        service.list(null, "kampus", 0, 20);
        verify(repo, times(2)).searchPage(any(), anyString(), anyString(), any(Pageable.class));
        service.list(null, null, 25, 20);
        service.list(null, null, 25, 20);
        verify(repo, times(2)).findByHiddenFalse(PageRequest.of(25, 20,
                org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Order.desc("publishedDate").nullsLast(),
                        org.springframework.data.domain.Sort.Order.desc("id"))));
    }

    @Test
    void detailIsCachedWhenFoundButNotWhenMissingOrHidden() {
        when(repo.findById(5L)).thenReturn(Optional.of(item(5, "Detay")));
        service.find(5L);
        assertEquals("Detay", service.find(5L).orElseThrow().title());
        verify(repo, times(1)).findById(5L);

        when(repo.findById(6L)).thenReturn(Optional.empty());
        service.find(6L);
        service.find(6L);
        verify(repo, times(2)).findById(6L);

        NewsItem hidden = item(7, "Gizli");
        hidden.setHidden(true);
        when(repo.findById(7L)).thenReturn(Optional.of(hidden));
        assertTrue(service.find(7L).isEmpty());
        assertTrue(service.find(7L).isEmpty());
        verify(repo, times(2)).findById(7L);
    }

    @Test
    void invalidatingNewsNamespaceReloads() {
        service.list(null, null, 0, 20);
        cache.invalidate("news");
        service.list(null, null, 0, 20);
        verify(repo, times(2)).findByHiddenFalse(any(Pageable.class));
    }

    @Test
    void pageAndDetailSurviveJsonRoundTripThroughRedis() {
        CacheService[] p = TestCaches.pair();
        NewsService a = new NewsService(repo);
        a.setCache(p[0]);
        NewsService b = new NewsService(repo);
        b.setCache(p[1]);
        when(repo.findById(9L)).thenReturn(Optional.of(item(9, "Detay")));
        var x = a.list(null, null, 0, 20);
        var y = b.list(null, null, 0, 20);
        verify(repo, times(1)).findByHiddenFalse(any(Pageable.class));
        assertEquals(x, y);
        var d1 = a.find(9L);
        var d2 = b.find(9L);
        verify(repo, times(1)).findById(9L);
        assertEquals(d1, d2);
    }

    @Test
    void worksWithoutCacheBean() {
        NewsService plain = new NewsService(repo);
        plain.list(null, null, 0, 20);
        plain.list(null, null, 0, 20);
        verify(repo, times(2)).findByHiddenFalse(any(Pageable.class));
    }
}
