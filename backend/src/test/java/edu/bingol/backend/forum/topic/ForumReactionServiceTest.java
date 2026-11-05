package edu.bingol.backend.forum.topic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.category.ForumCategory;
import edu.bingol.backend.forum.category.ForumCategoryRepository;
import edu.bingol.backend.forum.notify.spi.ForumEventPublisher;
import edu.bingol.backend.forum.topic.ForumTopicDtos.LikeState;
import edu.bingol.backend.forum.topic.dto.TopicView;
import edu.bingol.backend.forum.topic.spi.ForumTopicFollowLookup;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** Begeni (idempotent, atomik sayac, olay), kaydet, takip ve bildirim tercihi; hesap silme temizligi (H2). */
@SpringBootTest
class ForumReactionServiceTest {

    @MockitoBean edu.bingol.backend.common.RateLimiter limiter;
    @MockitoBean ForumEventPublisher events;

    @Autowired ForumReactionService reactions;
    @Autowired ForumTopicService service;
    @Autowired ForumTopicRepository topics;
    @Autowired ForumCategoryRepository cats;
    @Autowired UserRepository users;
    @Autowired ForumTopicFollowLookup followLookup;
    @Autowired ForumBookmarkService bookmarks;
    @Autowired ForumTopicAccountPurger purger;
    @Autowired JdbcTemplate jdbc;

    private ForumCategory cat;

    @BeforeEach
    void setUp() {
        org.springframework.context.i18n.LocaleContextHolder.setLocale(java.util.Locale.forLanguageTag("tr"));
        cat = ForumTestSupport.category(cats, "Tepki");
    }

    private User u(String n) {
        return ForumTestSupport.user(users, n);
    }

    private TopicView topic(User by) {
        return service.create(by.getId(), new ForumTopicDtos.CreateTopicRequest("Baslik", "govde", cat.getId(), false, List.of(), null), null);
    }

    private int likeCount(Long id) {
        return topics.findById(id).orElseThrow().getLikeCount();
    }

    @Test
    void likeIsIdempotentCountsOnceAndPublishesOneEvent() {
        User author = u("yazar");
        User fan = u("hayran");
        TopicView t = topic(author);
        LikeState a = reactions.like(fan.getId(), t.id());
        LikeState b = reactions.like(fan.getId(), t.id());
        assertTrue(a.liked() && b.liked());
        assertEquals(1, a.likeCount());
        assertEquals(1, b.likeCount(), "cift PUT sayaci arttirmaz");
        verify(events, times(1)).topicLiked(t.id(), fan.getId());
        assertTrue(service.get(fan.getId(), t.id()).likedByMe());
        assertFalse(service.get(author.getId(), t.id()).likedByMe());

        LikeState un = reactions.unlike(fan.getId(), t.id());
        LikeState un2 = reactions.unlike(fan.getId(), t.id());
        assertFalse(un.liked() || un2.liked());
        assertEquals(0, un.likeCount());
        assertEquals(0, un2.likeCount(), "cift DELETE sayaci negatife dusurmez");
    }

    @Test
    void ownTopicLikeCountsButNeverNotifies() {
        User author = u("yazar");
        TopicView t = topic(author);
        assertEquals(1, reactions.like(author.getId(), t.id()).likeCount());
        verify(events, never()).topicLiked(anyLong(), anyLong());
    }

    @Test
    void invisibleTopicCannotBeLiked() {
        User author = u("yazar");
        User fan = u("hayran");
        TopicView t = topic(author);
        topics.findById(t.id()).ifPresent(x -> {
            x.setStatus(ForumTopic.REMOVED);
            topics.save(x);
        });
        assertEquals("FORUM_TOPIC_NOT_FOUND", assertThrows(ApiException.class, () -> reactions.like(fan.getId(), t.id())).code());
        verify(events, never()).topicLiked(any(), any());
    }

    @Test
    void concurrentLikesFromManyUsersAreCountedExactly() throws Exception {
        User author = u("yazar");
        TopicView t = topic(author);
        int n = 12;
        List<User> fans = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            fans.add(u("f" + i));
        }
        ExecutorService pool = Executors.newFixedThreadPool(n);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<?>> fs = new ArrayList<>();
        for (User f : fans) {
            fs.add(pool.submit(() -> {
                go.await();
                reactions.like(f.getId(), t.id());
                return null;
            }));
        }
        go.countDown();
        for (Future<?> f : fs) {
            f.get();
        }
        pool.shutdown();
        assertEquals(n, likeCount(t.id()));
        assertEquals(n, jdbc.queryForObject("SELECT COUNT(*) FROM forum_topic_like WHERE topic_id = ?", Integer.class, t.id()));
    }

    @Test
    void concurrentDoublePutOfTheSameUserCountsOnce() throws Exception {
        User author = u("yazar");
        User fan = u("hayran");
        TopicView t = topic(author);
        ExecutorService pool = Executors.newFixedThreadPool(8);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<?>> fs = new ArrayList<>();
        for (int i = 0; i < 8; i++) {
            fs.add(pool.submit(() -> {
                go.await();
                reactions.like(fan.getId(), t.id());
                return null;
            }));
        }
        go.countDown();
        for (Future<?> f : fs) {
            f.get();
        }
        pool.shutdown();
        assertEquals(1, likeCount(t.id()), "ayni kisinin es zamanli PUT'lari tek begeni");
    }

    @Test
    void bookmarkIsIdempotentAndKeepsCounterInSync() {
        User author = u("yazar");
        User me = u("ben");
        TopicView t = topic(author);
        assertTrue(reactions.save(me.getId(), t.id()).saved());
        assertTrue(reactions.save(me.getId(), t.id()).saved());
        assertEquals(1, topics.findById(t.id()).orElseThrow().getBookmarkCount());
        assertTrue(service.get(me.getId(), t.id()).savedByMe());
        assertFalse(reactions.unsave(me.getId(), t.id()).saved());
        assertFalse(reactions.unsave(me.getId(), t.id()).saved());
        assertEquals(0, topics.findById(t.id()).orElseThrow().getBookmarkCount());
        // yorum kaydi sayaci etkilemez (B kullanir)
        assertTrue(bookmarks.save(me.getId(), ForumBookmark.COMMENT, 77L));
        assertFalse(bookmarks.save(me.getId(), ForumBookmark.COMMENT, 77L));
        assertEquals(java.util.Set.of(77L), bookmarks.savedAmong(me.getId(), ForumBookmark.COMMENT, List.of(77L, 78L)));
        assertTrue(bookmarks.unsave(me.getId(), ForumBookmark.COMMENT, 77L));
    }

    @Test
    void followAndNotificationPreferencesWorkForFollowersAndNonFollowers() {
        User author = u("yazar");
        User me = u("ben");
        TopicView t = topic(author);
        assertTrue(followLookup.notificationsEnabled(t.id(), me.getId()), "varsayilan acik");
        assertFalse(service.get(me.getId(), t.id()).followedByMe());

        assertTrue(reactions.follow(me.getId(), t.id()).following());
        assertTrue(reactions.follow(me.getId(), t.id()).following());
        assertTrue(service.get(me.getId(), t.id()).followedByMe());
        assertEquals(java.util.Set.of(me.getId()), followLookup.notifyFollowers(t.id(), 100));

        // takip ediyor ama bildirimi kapatti
        assertFalse(reactions.setNotifications(me.getId(), t.id(), false).enabled());
        assertTrue(followLookup.notifyFollowers(t.id(), 100).isEmpty());
        assertFalse(service.get(me.getId(), t.id()).notificationsEnabled());
        assertTrue(service.get(me.getId(), t.id()).followedByMe(), "takip surer");

        // takibi birakinca kapatma tercihi korunur
        assertFalse(reactions.unfollow(me.getId(), t.id()).following());
        assertFalse(service.get(me.getId(), t.id()).followedByMe());
        assertFalse(followLookup.notificationsEnabled(t.id(), me.getId()));
        assertTrue(reactions.setNotifications(me.getId(), t.id(), true).enabled());
        assertTrue(followLookup.notificationsEnabled(t.id(), me.getId()));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM forum_topic_follow WHERE topic_id = ? AND user_id = ?",
                Integer.class, t.id(), me.getId()), "varsayilana donunce satir kalmaz");

        // konu sahibi (takip etmeyen) bildirimleri kapatabilir
        assertFalse(reactions.setNotifications(author.getId(), t.id(), false).enabled());
        assertFalse(followLookup.notificationsEnabled(t.id(), author.getId()));
        assertFalse(service.get(author.getId(), t.id()).followedByMe());
        assertFalse(service.get(author.getId(), t.id()).notificationsEnabled());
    }

    @Test
    void accountPurgeScrubsTopicsAndDropsReactionsWithCounters() {
        User author = u("silinen");
        User other = u("diger");
        TopicView mine = topic(author);
        TopicView theirs = topic(other);
        reactions.like(author.getId(), theirs.id());
        reactions.save(author.getId(), theirs.id());
        reactions.follow(author.getId(), theirs.id());
        reactions.like(other.getId(), mine.id());
        ForumTestSupport.topic(topics, author.getId(), cat.getId(), "anon", 0, 0, true, 1);

        purger.purge(author.getId());

        ForumTopic t = topics.findById(mine.id()).orElseThrow();
        assertEquals("[silindi]", t.getTitle());
        assertEquals("[silindi]", t.getBody());
        assertTrue(t.getDeletedAt() != null);
        assertEquals("FORUM_TOPIC_NOT_FOUND", assertThrows(ApiException.class, () -> service.get(other.getId(), mine.id())).code());
        assertEquals(0, likeCount(theirs.id()), "silinen kullanicinin begenisi sayactan duser");
        assertEquals(0, topics.findById(theirs.id()).orElseThrow().getBookmarkCount());
        for (String table : List.of("forum_topic_like", "forum_bookmark", "forum_topic_follow", "forum_anon_alias")) {
            assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM " + table + " WHERE user_id = ?", Integer.class,
                    author.getId()), table);
        }
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM forum_topic WHERE user_id = ? AND deleted_at IS NULL",
                Integer.class, author.getId()));
        assertTrue(service.get(other.getId(), theirs.id()).title().equals("Baslik"), "baskasinin konusu etkilenmez");
    }
}
