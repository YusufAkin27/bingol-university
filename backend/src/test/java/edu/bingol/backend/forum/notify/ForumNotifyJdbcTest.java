package edu.bingol.backend.forum.notify;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.forum.ForumTestDb;
import edu.bingol.backend.forum.notify.ForumNotifyReader.CommentInfo;
import edu.bingol.backend.forum.notify.ForumNotifyReader.TopicInfo;
import edu.bingol.backend.forum.topic.spi.ForumTopicFollowLookup;
import edu.bingol.backend.i18n.Lang;
import java.util.List;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.JdbcTemplate;

/** Kalici tekrar defteri (ON CONFLICT DO NOTHING) ve JDBC okuyucu: gercek SQL, H2 (PostgreSQL kipi). */
class ForumNotifyJdbcTest {

    private JdbcTemplate jdbc;
    private JdbcForumNotifyLedger ledger;
    private JdbcForumNotifyReader reader;
    private ForumTopicFollowLookup spi;

    @SuppressWarnings("unchecked")
    @BeforeEach
    void setUp() {
        jdbc = ForumTestDb.create();
        ledger = new JdbcForumNotifyLedger(jdbc);
        ObjectProvider<ForumTopicFollowLookup> provider = mock(ObjectProvider.class);
        when(provider.getIfAvailable()).thenAnswer(inv -> spi);
        reader = new JdbcForumNotifyReader(jdbc, provider);
        jdbc.update("INSERT INTO forum_category (id, name_tr, name_en, name_ar) VALUES (1, 'Yemekhane', 'Cafeteria', NULL)");
    }

    @Test
    void ledgerAcceptsEachKeyOnlyOnce() {
        assertTrue(ledger.firstTime("TL", 5, 2, 1));
        assertFalse(ledger.firstTime("TL", 5, 2, 1));
        assertTrue(ledger.firstTime("TL", 5, 3, 1)); // baska eden
        assertTrue(ledger.firstTime("CL", 5, 2, 1)); // baska tur
        assertTrue(ledger.firstTime("TL", 6, 2, 1)); // baska hedef
        assertTrue(ledger.firstTime("TL", 5, 2, 9)); // baska alici
        assertEquals(5, jdbc.queryForObject("SELECT COUNT(*) FROM forum_notify_seen", Integer.class));
    }

    @Test
    void ledgerIsAtomicUnderConcurrency() throws Exception {
        int n = 8;
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger wins = new AtomicInteger();
        Thread[] ts = new Thread[n];
        for (int i = 0; i < n; i++) {
            ts[i] = new Thread(() -> {
                try {
                    go.await();
                    if (ledger.firstTime("TL", 77, 2, 1)) {
                        wins.incrementAndGet();
                    }
                } catch (Exception e) {
                    // yarista kaybeden hata alsa bile kazanan sayisini bozmaz
                }
            });
            ts[i].start();
        }
        go.countDown();
        for (Thread t : ts) {
            t.join();
        }
        assertEquals(1, wins.get());
    }

    @Test
    void readerMapsTopicCommentAndHidesRemovedAsInvisible() {
        ForumTestDb.topic(jdbc, 10, 1, true, "Baslik", "g", "ACTIVE", false, "2026-11-01 10:00:00");
        ForumTestDb.topic(jdbc, 11, 1, false, "Kaldirilmis", "g", "REMOVED", false, "2026-11-01 10:00:00");
        TopicInfo t = reader.topic(10).orElseThrow();
        assertTrue(t.anonymous() && t.visible());
        assertEquals(1L, t.authorId());
        assertFalse(reader.topic(11).orElseThrow().visible());
        assertTrue(reader.topic(404).isEmpty());

        ForumTestDb.comment(jdbc, 50, 10, 2, false, "ust", "ACTIVE", false, "2026-11-01 11:00:00");
        jdbc.update("INSERT INTO forum_comment (id, topic_id, user_id, parent_comment_id, body, anonymous, status, created_at)"
                + " VALUES (51, 10, 3, 50, 'yanit', TRUE, 'ACTIVE', TIMESTAMP '2026-11-01 12:00:00')");
        CommentInfo c = reader.comment(51).orElseThrow();
        assertEquals(50L, c.parentId());
        assertEquals(2L, c.parentAuthorId());
        assertTrue(c.anonymous() && c.visible());
        assertNull(reader.comment(50).orElseThrow().parentId());
        assertNull(reader.comment(50).orElseThrow().parentAuthorId());
    }

    @Test
    void categoryNameFallsBackToTurkishWhenLanguageMissing() {
        assertEquals("Yemekhane", reader.categoryName(1, Lang.TR));
        assertEquals("Cafeteria", reader.categoryName(1, Lang.EN));
        assertEquals("Yemekhane", reader.categoryName(1, Lang.AR)); // name_ar bos: Turkce
        assertNull(reader.categoryName(99, Lang.TR));
    }

    @Test
    void anonAliasMuteImageAndFollowFallbackSql() {
        jdbc.update("INSERT INTO forum_anon_alias (topic_id, user_id, n) VALUES (10, 3, 4)");
        assertEquals(4, reader.anonAlias(10, 3));
        assertNull(reader.anonAlias(10, 9));

        jdbc.update("INSERT INTO forum_user_mute (user_id, muted_user_id) VALUES (5, 2), (6, 2), (7, 8)");
        assertTrue(reader.muted(5, 2));
        assertFalse(reader.muted(2, 5));
        assertEquals(Set.of(5L, 6L), reader.mutersAmong(List.of(5L, 6L, 7L), 2));
        assertTrue(reader.mutersAmong(List.of(), 2).isEmpty());

        assertFalse(reader.topicHasImage(10));
        jdbc.update("INSERT INTO forum_topic_image (id, topic_id, media_id, position) VALUES (1, 10, 1, 0)");
        assertTrue(reader.topicHasImage(10));

        // SPI yokken duz SQL: follow=TRUE ve notify=TRUE olanlar, kimlik sirali
        jdbc.update("INSERT INTO forum_topic_follow (topic_id, user_id, notify, follow) VALUES "
                + "(10, 4, TRUE, TRUE), (10, 2, TRUE, TRUE), (10, 3, FALSE, TRUE), (10, 9, FALSE, FALSE), (10, 8, TRUE, FALSE)");
        assertEquals(List.of(2L, 4L), reader.notifyingFollowers(10, 10));
        assertEquals(List.of(2L), reader.notifyingFollowers(10, 1));
        assertTrue(reader.topicNotificationsOff(10, 3));
        assertTrue(reader.topicNotificationsOff(10, 9)); // takip etmeyen ama bildirimi kapatan
        assertFalse(reader.topicNotificationsOff(10, 4));
        assertFalse(reader.topicNotificationsOff(10, 55)); // satir yok: varsayilan acik
    }

    @Test
    void followSpiTakesPrecedenceWhenPresent() {
        spi = new ForumTopicFollowLookup() {
            @Override
            public Set<Long> notifyFollowers(Long topicId, int limit) {
                return Set.of(30L, 10L, 20L);
            }

            @Override
            public boolean notificationsEnabled(Long topicId, Long userId) {
                return userId != 20L;
            }
        };
        assertEquals(List.of(10L, 20L, 30L), reader.notifyingFollowers(1, 10));
        assertEquals(List.of(10L, 20L), reader.notifyingFollowers(1, 2));
        assertTrue(reader.topicNotificationsOff(1, 20));
        assertFalse(reader.topicNotificationsOff(1, 10));
    }
}
