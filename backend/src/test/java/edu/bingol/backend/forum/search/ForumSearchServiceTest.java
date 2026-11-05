package edu.bingol.backend.forum.search;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.search.ForumSearchRepository.Hit;
import edu.bingol.backend.forum.topic.dto.ForumPage;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import edu.bingol.backend.forum.topic.spi.ForumMuteLookup;
import edu.bingol.backend.forum.topic.spi.ForumTopicSummaries;
import edu.bingol.backend.moderation.BlockService;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;

class ForumSearchServiceTest {

    /** Cagrilari kaydeden sahte depo. */
    static class FakeRepo implements ForumSearchRepository {
        List<Hit> hits = new ArrayList<>();
        Set<Long> lastExcluded;
        int lastOffset = -1;
        int lastLimit = -1;
        String lastQ;
        ForumSearchSort lastSort;
        Long lastCat;
        List<Long> popularIds = List.of();

        @Override
        public List<Hit> search(String q, Long categoryId, ForumSearchSort sort, Set<Long> excludedAuthors, int offset,
                                int limit) {
            lastQ = q;
            lastCat = categoryId;
            lastSort = sort;
            lastExcluded = excludedAuthors;
            lastOffset = offset;
            lastLimit = limit;
            return hits.size() <= limit ? hits : hits.subList(0, limit);
        }

        @Override
        public List<Long> popular(Set<Long> excludedAuthors, int limit) {
            lastExcluded = excludedAuthors;
            return popularIds;
        }
    }

    private final FakeRepo repo = new FakeRepo();
    private final BlockService blocks = mock(BlockService.class);
    private final ForumMuteLookup muteLookup = mock(ForumMuteLookup.class);
    private final Set<Long> invisible = new java.util.HashSet<>();
    private ForumSearchService service;

    private static TopicSummary summary(long id) {
        return new TopicSummary(id, "t" + id, "", null, null, null, null, 0, 0, false, false, false, null, 0, false,
                false, false, false, false, "ACTIVE");
    }

    @SuppressWarnings("unchecked")
    @BeforeEach
    void setUp() {
        ForumTopicSummaries summaries = (ids, viewer) -> ids.stream().filter(i -> !invisible.contains(i))
                .map(ForumSearchServiceTest::summary).toList();
        ObjectProvider<ForumTopicSummaries> sp = mock(ObjectProvider.class);
        when(sp.getObject()).thenReturn(summaries);
        ObjectProvider<ForumMuteLookup> mp = mock(ObjectProvider.class);
        when(mp.getIfAvailable()).thenReturn(muteLookup);
        service = new ForumSearchService(repo, sp, blocks, mp);
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of(11L));
        when(muteLookup.mutedBy(anyLong())).thenReturn(Set.of(12L));
    }

    @Test
    void queryNormalizationAndLengthRules() {
        assertEquals("yemek listesi", ForumSearchService.normalize("  yemek   listesi "));
        ApiException tooShort = assertThrows(ApiException.class, () -> ForumSearchService.normalize(" a "));
        assertEquals("FORUM_SEARCH_QUERY_TOO_SHORT", tooShort.code());
        assertThrows(ApiException.class, () -> ForumSearchService.normalize(null));
        assertEquals(100, ForumSearchService.normalize("x".repeat(500)).length());
        assertEquals("%a\\%b\\_c\\\\d%", ForumSearchService.likePattern("a%b_c\\d")); // LIKE kacisi
    }

    @Test
    void sortIsWhitelisted() {
        assertEquals(ForumSearchSort.RELEVANCE, ForumSearchSort.parse(null));
        assertEquals(ForumSearchSort.NEWEST, ForumSearchSort.parse("newest"));
        ApiException e = assertThrows(ApiException.class, () -> ForumSearchSort.parse("id; DROP TABLE x"));
        assertEquals("FORUM_SEARCH_BAD_SORT", e.code());
        assertTrue(PgForumSearchRepository.orderBy(ForumSearchSort.RELEVANCE).startsWith("b.rank"));
        assertTrue(PgForumSearchRepository.orderBy(ForumSearchSort.NEWEST).startsWith("t.created_at"));
        assertTrue(PgForumSearchRepository.orderBy(ForumSearchSort.POPULAR).startsWith("(t.like_count"));
    }

    @Test
    void blockedAndMutedAuthorsAreExcludedButNotViewer() {
        repo.hits.add(new Hit(1, "TITLE", null));
        service.search(5L, "yemek", null, null, null, null);
        assertEquals(Set.of(11L, 12L), repo.lastExcluded);
        assertEquals("yemek", repo.lastQ);
        assertEquals(ForumSearchSort.RELEVANCE, repo.lastSort);
        assertNull(repo.lastCat);
    }

    @Test
    void pagingFetchesOneExtraAndBuildsOpaqueCursorWithOffsetCap() {
        for (long i = 1; i <= 40; i++) {
            repo.hits.add(new Hit(i, "BODY", "parca " + i));
        }
        ForumPage<ForumSearchItem> p1 = service.search(5L, "yemek", 3L, "NEWEST", null, 10);
        assertEquals(11, repo.lastLimit);
        assertEquals(0, repo.lastOffset);
        assertEquals(3L, repo.lastCat);
        assertEquals(ForumSearchSort.NEWEST, repo.lastSort);
        assertEquals(10, p1.items().size());
        assertNotNull(p1.nextCursor());
        assertEquals("BODY", p1.items().get(0).matchedIn());
        assertEquals("parca 1", p1.items().get(0).snippet());

        service.search(5L, "yemek", null, null, p1.nextCursor(), 10);
        assertEquals(10, repo.lastOffset);

        // sinirsiz OFFSET yok: tavan asilinca bos
        String deep = ForumSearchService.encodeOffset(ForumSearchService.MAX_OFFSET);
        assertTrue(service.search(5L, "yemek", null, null, deep, 10).items().isEmpty());
        assertEquals(0, ForumSearchService.decodeOffset("!!bozuk!!"));
        assertEquals(ForumSearchService.MAX_OFFSET,
                ForumSearchService.decodeOffset(ForumSearchService.encodeOffset(99999)));
    }

    @Test
    void sizeIsClampedAndInvisibleTopicsAreDroppedKeepingOrder() {
        repo.hits.add(new Hit(3, "TITLE", null));
        repo.hits.add(new Hit(2, "COMMENT", "yorum parcasi"));
        repo.hits.add(new Hit(1, "CATEGORY", null));
        invisible.add(2L);
        ForumPage<ForumSearchItem> p = service.search(5L, "yemek", null, null, null, 9999);
        assertEquals(ForumSearchService.MAX_SIZE + 1, repo.lastLimit);
        assertEquals(List.of(3L, 1L), p.items().stream().map(i -> i.topic().id()).toList());
        assertNull(p.nextCursor());
        assertEquals("CATEGORY", p.items().get(1).matchedIn());
    }

    @Test
    void popularReturnsSummariesOrNothingWhenEmpty() {
        assertTrue(service.popular(5L).isEmpty());
        repo.popularIds = List.of(7L, 8L);
        assertEquals(2, service.popular(5L).size());
        assertEquals(Set.of(11L, 12L), repo.lastExcluded);
    }

    @Test
    void sqlHelpers() {
        assertEquals(List.of(-1L), PgForumSearchRepository.excludedOrSentinel(Set.of()));
        assertEquals(List.of(4L), PgForumSearchRepository.excludedOrSentinel(Set.of(4L)));
        assertEquals("ilk parca", PgForumSearchRepository.clean("  ~~~ilk~~~   parca "));
        assertNull(PgForumSearchRepository.clean("~~~  ~~~"));
        assertNull(PgForumSearchRepository.clean(null));
        assertEquals(160, PgForumSearchRepository.clean("x".repeat(300)).length());
    }
}
