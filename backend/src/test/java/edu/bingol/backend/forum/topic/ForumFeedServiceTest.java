package edu.bingol.backend.forum.topic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.category.ForumCategory;
import edu.bingol.backend.forum.category.ForumCategoryRepository;
import edu.bingol.backend.forum.topic.ForumFeedService.Sort;
import edu.bingol.backend.forum.topic.dto.ForumPage;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import edu.bingol.backend.forum.topic.spi.ForumTopicStateService;
import edu.bingol.backend.forum.topic.spi.ForumTopicSummaries;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.post.follow.UserFollow;
import edu.bingol.backend.post.follow.UserFollowRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/**
 * Akis siralamalari ve KARARLI imlec: her sayfalama boyutunda tekrarlayan/atlanan konu yok, sira beklenen formulle
 * ayni. (H2; Her test kendi kategorisini kullanir.)
 */
@SpringBootTest
class ForumFeedServiceTest {

    @MockitoBean edu.bingol.backend.common.RateLimiter limiter;

    @Autowired ForumFeedService feed;
    @Autowired ForumTopicRepository topics;
    @Autowired ForumCategoryRepository cats;
    @Autowired UserRepository users;
    @Autowired UserFollowRepository follows;
    @Autowired ForumTopicStateService state;
    @Autowired ForumReactionService reactions;
    @Autowired BlockService blocks;
    @Autowired ForumTopicSummaries summaries;

    @BeforeEach
    void tr() {
        org.springframework.context.i18n.LocaleContextHolder.setLocale(java.util.Locale.forLanguageTag("tr"));
    }

    private User u(String n) {
        return ForumTestSupport.user(users, n);
    }

    /** Tum sayfalari dolasir; sayfa boyutu {@code size}. */
    private List<Long> walk(Sort sort, Long cat, Long viewer, int size) {
        List<Long> ids = new ArrayList<>();
        String cursor = null;
        for (int guard = 0; guard < 100; guard++) {
            ForumPage<TopicSummary> p = feed.feed(viewer, sort, cat, cursor, size);
            assertTrue(p.items().size() <= size, "sayfa boyutu asilmaz");
            p.items().forEach(i -> ids.add(i.id()));
            cursor = p.nextCursor();
            if (cursor == null) {
                return ids;
            }
            assertFalse(p.items().isEmpty(), "imlec varken bos sayfa olmaz");
        }
        throw new AssertionError("imlec sonlanmadi");
    }

    private List<ForumTopic> seed(User author, ForumCategory c, int n, long seed) {
        Random r = new Random(seed);
        List<ForumTopic> out = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            // dar aralik: cok sayida esit puan/zaman (beraberlik kirici kimlik sinanir)
            out.add(ForumTestSupport.topic(topics, author.getId(), c.getId(), "k" + i, r.nextInt(4), r.nextInt(3), false,
                    10 * (r.nextInt(3) + 1)));
        }
        return out;
    }

    @Test
    void newestPagesAreStableAndPinnedComeFirstOnlyOnce() {
        User a = u("yazar");
        User me = u("ben");
        ForumCategory c = ForumTestSupport.category(cats, "Yeni");
        List<ForumTopic> ts = seed(a, c, 14, 1);
        ForumTopic pinned = ts.get(2);
        state.pin(pinned.getId());

        List<Long> expected = new ArrayList<>();
        expected.add(pinned.getId());
        ts.stream().filter(t -> !t.getId().equals(pinned.getId())).map(ForumTopic::getId)
                .sorted(Comparator.reverseOrder()).forEach(expected::add);
        for (int size : new int[] {1 + 1, 3, 4, 5, 14, 30}) {
            if (size == 2) {
                continue; // pinned + 1: cok kucuk sayfa da dogru olmali
            }
            assertEquals(expected, walk(Sort.NEWEST, c.getId(), me.getId(), size), "size=" + size);
        }
        assertEquals(expected, walk(Sort.NEWEST, c.getId(), me.getId(), 2), "size=2");
    }

    @Test
    void mostCommentedAndPopularUseCompositeCursorWithoutRepeats() {
        User a = u("yazar");
        User me = u("ben");
        ForumCategory c = ForumTestSupport.category(cats, "Say");
        List<ForumTopic> ts = seed(a, c, 25, 7);

        List<Long> mc = ts.stream().sorted(Comparator.comparingInt(ForumTopic::getCommentCount).reversed()
                .thenComparing(Comparator.comparing(ForumTopic::getId).reversed())).map(ForumTopic::getId).toList();
        List<Long> pop = ts.stream().sorted(Comparator.comparingInt((ForumTopic t) -> t.getLikeCount() + 2 * t.getCommentCount())
                .reversed().thenComparing(Comparator.comparing(ForumTopic::getId).reversed())).map(ForumTopic::getId).toList();
        for (int size : new int[] {1, 2, 4, 7, 25, 30}) {
            assertEquals(mc, walk(Sort.MOST_COMMENTED, c.getId(), me.getId(), size), "MOST_COMMENTED size=" + size);
            assertEquals(pop, walk(Sort.POPULAR, c.getId(), me.getId(), size), "POPULAR size=" + size);
        }
    }

    @Test
    void forYouFollowsTheDocumentedFormulaAndIsStableAcrossPages() {
        User a = u("yazar");
        User fav = u("sevilen");
        User me = u("ben");
        ForumCategory c = ForumTestSupport.category(cats, "Sana");
        List<ForumTopic> ts = new ArrayList<>(seed(a, c, 20, 3));
        // ayni sayac/zamanda iki konu: takip ettigim yazarinki once gelmeli (+1 bonus)
        ForumTopic plain = ForumTestSupport.topic(topics, a.getId(), c.getId(), "duz", 2, 1, false, 30);
        ForumTopic liked = ForumTestSupport.topic(topics, fav.getId(), c.getId(), "sevilen", 2, 1, false, 30);
        ForumTopic anonFav = ForumTestSupport.topic(topics, fav.getId(), c.getId(), "anonim", 2, 1, true, 30);
        ts.addAll(List.of(plain, liked, anonFav));
        follows.saveAndFlush(new UserFollow(me.getId(), fav.getId()));
        // Ben bu kategoride konu actim: kategori bonusu (+0.5) hepsine esit gelir
        ForumTestSupport.topic(topics, me.getId(), c.getId(), "benim", 0, 0, false, 600);

        List<Long> expected = new ArrayList<>(topics.findAll(org.springframework.data.domain.PageRequest.of(0, 1000)).stream()
                .filter(t -> t.getCategoryId().equals(c.getId())).sorted(
                        Comparator.<ForumTopic>comparingDouble(t -> ForumFeedService.key(t, t.getUserId().equals(fav.getId()), true))
                                .reversed().thenComparing(Comparator.comparing(ForumTopic::getId).reversed()))
                .map(ForumTopic::getId).toList());
        for (int size : new int[] {1, 3, 5, 8, 30}) {
            List<Long> got = walk(Sort.FOR_YOU, c.getId(), me.getId(), size);
            assertEquals(expected, got, "FOR_YOU size=" + size);
            assertEquals(new HashSet<>(got).size(), got.size(), "tekrar yok");
        }
        List<Long> order = walk(Sort.FOR_YOU, c.getId(), me.getId(), 30);
        assertTrue(order.indexOf(liked.getId()) < order.indexOf(plain.getId()), "takip ettigim yazar bonusu");
        assertTrue(order.indexOf(anonFav.getId()) > order.indexOf(liked.getId()), "anonim konuda yazar bonusu YOK");
        // Daha cok etkilesim ve daha yeni etkinlik ustte
        ForumTopic hot = ForumTestSupport.topic(topics, a.getId(), c.getId(), "sicak", 50, 20, false, 1);
        assertEquals(hot.getId(), walk(Sort.FOR_YOU, c.getId(), me.getId(), 30).get(0));
    }

    @Test
    void followingFeedHasFollowedTopicsAndOpenTopicsOfFollowedUsersOnly() {
        User a = u("takipEdilen");
        User b = u("baska");
        User me = u("ben");
        ForumCategory c = ForumTestSupport.category(cats, "Takip");
        ForumTopic ofFollowed = ForumTestSupport.topic(topics, a.getId(), c.getId(), "a-acik", 0, 0, false, 5);
        ForumTopic ofFollowedAnon = ForumTestSupport.topic(topics, a.getId(), c.getId(), "a-anonim", 0, 0, true, 5);
        ForumTopic followedTopic = ForumTestSupport.topic(topics, b.getId(), c.getId(), "b-takip", 0, 0, false, 5);
        ForumTopic unrelated = ForumTestSupport.topic(topics, b.getId(), c.getId(), "b-ilgisiz", 0, 0, false, 5);
        follows.saveAndFlush(new UserFollow(me.getId(), a.getId()));
        reactions.follow(me.getId(), followedTopic.getId());

        List<Long> got = walk(Sort.FOLLOWING, c.getId(), me.getId(), 2);
        assertEquals(Set.of(ofFollowed.getId(), followedTopic.getId()), new HashSet<>(got));
        assertFalse(got.contains(ofFollowedAnon.getId()), "anonim konu yazar takibiyle sizdirilmaz");
        assertFalse(got.contains(unrelated.getId()));
        reactions.unfollow(me.getId(), followedTopic.getId());
        assertEquals(List.of(ofFollowed.getId()), walk(Sort.FOLLOWING, c.getId(), me.getId(), 5));
    }

    @Test
    void blockedAuthorsAndRemovedTopicsAreAbsentFromEveryList() {
        User a = u("yazar");
        User bad = u("engelli");
        User me = u("ben");
        ForumCategory c = ForumTestSupport.category(cats, "Gizle");
        ForumTopic ok = ForumTestSupport.topic(topics, a.getId(), c.getId(), "ok", 1, 1, false, 5);
        ForumTopic fromBad = ForumTestSupport.topic(topics, bad.getId(), c.getId(), "kotu", 9, 9, false, 5);
        ForumTopic anonFromBad = ForumTestSupport.topic(topics, bad.getId(), c.getId(), "kotu-anonim", 9, 9, true, 5);
        ForumTopic removed = ForumTestSupport.topic(topics, a.getId(), c.getId(), "kaldirilmis", 9, 9, false, 5);
        state.remove(removed.getId(), "ihlal");
        blocks.block(me.getId(), bad.getId());
        for (Sort s : Sort.values()) {
            List<Long> got = walk(s, c.getId(), me.getId(), 10);
            assertFalse(got.contains(fromBad.getId()) || got.contains(anonFromBad.getId()), s + ": engelli yazar");
            assertFalse(got.contains(removed.getId()), s + ": kaldirilmis");
            if (s != Sort.FOLLOWING) {
                assertEquals(List.of(ok.getId()), got, s.name());
            }
        }
        assertEquals(List.of(ok.getId()), summaries.summaries(
                List.of(removed.getId(), fromBad.getId(), ok.getId(), anonFromBad.getId()), me.getId()).stream().map(TopicSummary::id).toList());
    }

    @Test
    void summariesPreserveRequestedOrderAndCardFields() {
        User a = u("yazar");
        User me = u("ben");
        ForumCategory c = ForumTestSupport.category(cats, "Kart");
        ForumTopic t1 = ForumTestSupport.topic(topics, a.getId(), c.getId(), "bir", 3, 2, false, 5);
        ForumTopic t2 = ForumTestSupport.topic(topics, me.getId(), c.getId(), "iki", 0, 0, true, 5);
        List<TopicSummary> s = summaries.summaries(List.of(t2.getId(), t1.getId(), t2.getId()), me.getId());
        assertEquals(List.of(t2.getId(), t1.getId()), s.stream().map(TopicSummary::id).toList());
        assertTrue(s.get(0).mine());
        assertTrue(s.get(0).author().anonymous());
        assertEquals(3, s.get(1).likeCount());
        assertEquals(2, s.get(1).commentCount());
        assertEquals(c.getId(), s.get(1).category().id());
        assertNull(s.get(1).thumbnail());
        assertFalse(s.get(1).hasPoll() || s.get(1).pinned() || s.get(1).locked() || s.get(1).canModerate());
        assertNotNull(s.get(1).createdAt());
    }

    @Test
    void invalidSortCursorAndSizeAreHandled() {
        User me = u("ben");
        ForumCategory c = ForumTestSupport.category(cats, "Gecersiz");
        assertEquals("FORUM_SORT_INVALID", assertThrows(ApiException.class, () -> ForumFeedService.parseSort("RASTGELE")).code());
        assertEquals(Sort.FOR_YOU, ForumFeedService.parseSort(null));
        assertEquals(Sort.POPULAR, ForumFeedService.parseSort("popular"));
        assertEquals("FORUM_CURSOR_INVALID", assertThrows(ApiException.class,
                () -> feed.feed(me.getId(), Sort.NEWEST, c.getId(), "!!!bozuk", 5)).code());
        // baska siralamanin imleci kabul edilmez
        ForumTestSupport.topic(topics, me.getId(), c.getId(), "x", 0, 0, false, 5);
        ForumTestSupport.topic(topics, me.getId(), c.getId(), "y", 0, 0, false, 5);
        String newestCursor = feed.feed(me.getId(), Sort.NEWEST, c.getId(), null, 1).nextCursor();
        assertNotNull(newestCursor);
        assertEquals("FORUM_CURSOR_INVALID", assertThrows(ApiException.class,
                () -> feed.feed(me.getId(), Sort.POPULAR, c.getId(), newestCursor, 5)).code());
        assertEquals(2, feed.feed(me.getId(), Sort.NEWEST, c.getId(), null, 500).items().size(), "size en cok 30'a iner");
        assertTrue(feed.feed(me.getId(), Sort.NEWEST, c.getId(), null, 0).items().size() >= 1, "size en az 1");
        assertEquals(0, feed.feed(me.getId(), Sort.FOR_YOU, ForumTestSupport.category(cats, "Bos").getId(), null, 10).items().size());
    }
}
