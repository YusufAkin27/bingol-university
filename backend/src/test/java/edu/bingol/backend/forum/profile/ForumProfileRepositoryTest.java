package edu.bingol.backend.forum.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.forum.ForumTestDb;
import edu.bingol.backend.forum.profile.ForumProfileRepository.CommentRow;
import edu.bingol.backend.forum.profile.ForumProfileRepository.Cursor;
import edu.bingol.backend.forum.profile.ForumProfileRepository.Row;
import edu.bingol.backend.forum.profile.ForumProfileRepository.SavedRow;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

/** Profil kimlik secimi: anonimlik, silinmis/kaldirilmis, anonim konu yazarinin adli yorumu, imlec, sayaclar. */
class ForumProfileRepositoryTest {

    private JdbcTemplate jdbc;
    private ForumProfileRepository repo;

    @BeforeEach
    void setUp() {
        jdbc = ForumTestDb.create();
        repo = new ForumProfileRepository(jdbc);
        // kullanici 1 = sahip. Konular: 10 acik, 11 anonim, 12 silinmis, 13 kaldirilmis, 14 acik (yeni)
        ForumTestDb.topic(jdbc, 10, 1, false, "Acik", "gövde", "ACTIVE", false, "2026-11-01 10:00:00");
        ForumTestDb.topic(jdbc, 11, 1, true, "Gizli", "gövde", "ACTIVE", false, "2026-11-01 11:00:00");
        ForumTestDb.topic(jdbc, 12, 1, false, "Silinmis", "x", "ACTIVE", true, "2026-11-01 12:00:00");
        ForumTestDb.topic(jdbc, 13, 1, false, "Kaldirilmis", "x", "REMOVED", false, "2026-11-01 13:00:00");
        ForumTestDb.topic(jdbc, 14, 1, false, "Yeni", "x", "ACTIVE", false, "2026-11-02 09:00:00");
        // baskasinin konulari: 20 acik, 21 anonim (sahibi 2)
        ForumTestDb.topic(jdbc, 20, 2, false, "Baskasi", "x", "ACTIVE", false, "2026-11-01 08:00:00");
        ForumTestDb.topic(jdbc, 21, 2, true, "Baskasi gizli", "x", "ACTIVE", false, "2026-11-01 08:30:00");
    }

    private static List<Long> ids(List<Row> rows) {
        return rows.stream().map(Row::id).toList();
    }

    @Test
    void ownTopicsIncludeAnonymousButNotDeletedOrRemoved() {
        assertEquals(List.of(14L, 11L, 10L), ids(repo.topics(1, true, null, 20)));
    }

    @Test
    void othersSeeOnlyNonAnonymousVisibleTopics() {
        assertEquals(List.of(14L, 10L), ids(repo.topics(1, false, null, 20)));
        assertEquals(2, repo.publicTopicCount(1));
    }

    @Test
    void keysetCursorPagesWithoutOverlapOrGaps() {
        List<Row> p1 = repo.topics(1, true, null, 2);
        assertEquals(List.of(14L, 11L), ids(p1));
        Row last = p1.get(1);
        List<Row> p2 = repo.topics(1, true, new Cursor(last.at(), last.id()), 2);
        assertEquals(List.of(10L), ids(p2));
        // ayni zaman damgasi: kimlikle ayrilir
        ForumTestDb.topic(jdbc, 15, 1, false, "Ayni an", "x", "ACTIVE", false, "2026-11-02 09:00:00");
        assertEquals(List.of(15L, 14L, 11L, 10L), ids(repo.topics(1, true, null, 20)));
        Row r15 = repo.topics(1, true, null, 1).get(0);
        assertEquals(15L, r15.id());
        assertEquals(List.of(14L, 11L), ids(repo.topics(1, true, new Cursor(r15.at(), r15.id()), 2)));
    }

    @Test
    void commentsHideAnonymousAndAnonymousTopicAuthorsNamedComments() {
        // sahip 1: 10 numarali konuya adli yorum (30), anonim yorum (31), anonim konusuna ADIYLA yorum (32), silinmis (33)
        ForumTestDb.comment(jdbc, 30, 10, 1, false, "adli", "ACTIVE", false, "2026-11-03 10:00:00");
        ForumTestDb.comment(jdbc, 31, 10, 1, true, "anonim", "ACTIVE", false, "2026-11-03 11:00:00");
        ForumTestDb.comment(jdbc, 32, 11, 1, false, "kendi anonim konuma adli", "ACTIVE", false, "2026-11-03 12:00:00");
        ForumTestDb.comment(jdbc, 33, 10, 1, false, "silinmis", "ACTIVE", true, "2026-11-03 13:00:00");
        // baskasinin anonim konusuna adli yorum (34): gorunur (sahibi o konunun yazari degil)
        ForumTestDb.comment(jdbc, 34, 21, 1, false, "baskasinin gizli konusuna", "ACTIVE", false, "2026-11-03 14:00:00");
        // kaldirilmis konuda yorum (35) hic listelenmez
        ForumTestDb.comment(jdbc, 35, 13, 1, false, "kaldirilmis konuda", "ACTIVE", false, "2026-11-03 15:00:00");

        List<Long> own = repo.comments(1, true, null, 20).stream().map(CommentRow::id).toList();
        assertEquals(List.of(34L, 32L, 31L, 30L), own);
        List<Long> others = repo.comments(1, false, null, 20).stream().map(CommentRow::id).toList();
        assertEquals(List.of(34L, 30L), others);
        assertEquals(2, repo.publicCommentCount(1));
        assertEquals("Baskasi gizli", repo.comments(1, false, null, 1).get(0).topicTitle());
    }

    @Test
    void followingAndSavedAreOrderedByActionTime() {
        jdbc.update("INSERT INTO forum_topic_follow (topic_id, user_id, notify, follow, created_at) VALUES "
                + "(20, 5, TRUE, TRUE, TIMESTAMP '2026-11-04 10:00:00'), "
                + "(10, 5, TRUE, TRUE, TIMESTAMP '2026-11-04 11:00:00'), "
                + "(14, 5, FALSE, FALSE, TIMESTAMP '2026-11-04 12:00:00'), "   // takip etmiyor: yalniz bildirim kapatma
                + "(12, 5, TRUE, TRUE, TIMESTAMP '2026-11-04 13:00:00')");        // silinmis konu
        assertEquals(List.of(10L, 20L), ids(repo.following(5, null, 20)));

        jdbc.update("INSERT INTO forum_bookmark (user_id, target_type, target_id, created_at) VALUES "
                + "(5, 'TOPIC', 20, TIMESTAMP '2026-11-04 10:00:00'), "
                + "(5, 'COMMENT', 77, TIMESTAMP '2026-11-04 11:00:00'), "
                + "(6, 'TOPIC', 10, TIMESTAMP '2026-11-04 12:00:00')");
        List<SavedRow> saved = repo.saved(5, null, 20);
        assertEquals(2, saved.size());
        assertEquals("COMMENT", saved.get(0).type());
        assertEquals(77L, saved.get(0).targetId());
        assertEquals("TOPIC", saved.get(1).type());
        List<SavedRow> next = repo.saved(5, new Cursor(saved.get(0).at(), saved.get(0).targetId()), 20);
        assertEquals(1, next.size());
        assertEquals(20L, next.get(0).targetId());
    }

    @Test
    void commentContextOnlyForVisibleTopics() {
        ForumTestDb.comment(jdbc, 40, 10, 2, false, "a", "ACTIVE", false, "2026-11-03 10:00:00");
        ForumTestDb.comment(jdbc, 41, 12, 2, false, "b", "ACTIVE", false, "2026-11-03 10:00:00"); // silinmis konu
        var ctx = repo.commentContext(List.of(40L, 41L, 999L));
        assertEquals(1, ctx.size());
        assertEquals(10L, ctx.get(40L).topicId());
        assertEquals("Acik", ctx.get(40L).title());
        assertTrue(repo.commentContext(List.of()).isEmpty());
    }

    @Test
    void cursorCodecRoundTripsAndRejectsGarbage() {
        Instant at = Instant.parse("2026-11-04T10:15:30.123456Z");
        String c = ForumProfileService.encode(at, 42);
        Cursor back = ForumProfileService.decode(c);
        assertNotNull(back);
        assertEquals(at, back.at());
        assertEquals(42L, back.id());
        assertNull(ForumProfileService.decode("!!"));
        assertNull(ForumProfileService.decode(null));
        assertNull(ForumProfileService.decode(""));
        assertFalse(ForumProfileService.decode(c) == null);
        assertEquals(15, ForumProfileService.clamp(null));
        assertEquals(30, ForumProfileService.clamp(500));
        assertEquals(15, ForumProfileService.clamp(0));
    }
}
