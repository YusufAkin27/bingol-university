package edu.bingol.backend.search;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.search.SearchService.SearchResult;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

class SearchServiceTest {

    @Test
    void mergesProvidersGroupedByTypeAndCapsLimit() {
        SearchProvider news = provider(SearchType.NEWS, hits(SearchType.NEWS, 30));
        SearchProvider events = provider(SearchType.EVENT, hits(SearchType.EVENT, 1));
        // Sirasiz verilse de gruplar SearchType sirasinda gelir
        SearchService s = new SearchService(List.of(events, news));

        SearchResult r = s.search("  kampus  ", null, 100);

        assertEquals("kampus", r.q());
        assertEquals(2, r.groups().size());
        assertEquals(SearchType.NEWS, r.groups().get(0).type());
        assertEquals(SearchService.MAX_LIMIT, r.groups().get(0).items().size());
        assertEquals(SearchType.EVENT, r.groups().get(1).type());
        verify(news).search("kampus", SearchService.MAX_LIMIT);
    }

    @Test
    void defaultLimitIsFive() {
        SearchProvider news = provider(SearchType.NEWS, List.of());
        new SearchService(List.of(news)).search("ab", null, null);

        verify(news).search("ab", SearchService.DEFAULT_LIMIT);
    }

    @Test
    void typeFilterSkipsOtherProviders() {
        SearchProvider news = provider(SearchType.NEWS, hits(SearchType.NEWS, 1));
        SearchProvider events = provider(SearchType.EVENT, hits(SearchType.EVENT, 1));

        SearchResult r = new SearchService(List.of(news, events)).search("ab", SearchType.EVENT, 5);

        assertEquals(1, r.groups().size());
        assertEquals(SearchType.EVENT, r.groups().get(0).type());
        org.mockito.Mockito.verify(news, org.mockito.Mockito.never()).search("ab", 5);
    }

    @Test
    void failingProviderIsSkippedWithoutBreakingSearch() {
        SearchProvider bad = mock(SearchProvider.class);
        when(bad.type()).thenReturn(SearchType.COMMUNITY);
        when(bad.search("ab", 5)).thenThrow(new IllegalStateException("db down"));
        SearchProvider ok = provider(SearchType.NEWS, hits(SearchType.NEWS, 2));

        SearchResult r = new SearchService(List.of(bad, ok)).search("ab", null, 5);

        assertEquals(1, r.groups().size());
        assertEquals(SearchType.NEWS, r.groups().get(0).type());
    }

    @Test
    void tooShortQueryIs400() {
        SearchService s = new SearchService(List.of());

        ApiException e = assertThrows(ApiException.class, () -> s.search(" a ", null, 5));

        assertEquals(400, e.status().value());
    }

    @Test
    void likePatternEscapesWildcards() {
        assertEquals("%100\\%\\_a\\\\b%", SearchQuery.likePattern("100%_a\\b"));
        assertEquals("%ders%", SearchQuery.likePattern("ders"));
    }

    @Test
    void normalizeCollapsesWhitespaceAndCapsLength() {
        assertEquals("a b", SearchQuery.normalize("  a \t  b "));
        assertEquals(SearchQuery.MAX_LEN, SearchQuery.normalize("x".repeat(500)).length());
    }

    private static SearchProvider provider(SearchType type, List<SearchHit> result) {
        SearchProvider p = mock(SearchProvider.class);
        when(p.type()).thenReturn(type);
        when(p.search(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyInt()))
                .thenReturn(result);
        return p;
    }

    private static List<SearchHit> hits(SearchType type, int n) {
        List<SearchHit> l = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            l.add(new SearchHit(type, (long) i, "t" + i, null, null, null));
        }
        return l;
    }
}
