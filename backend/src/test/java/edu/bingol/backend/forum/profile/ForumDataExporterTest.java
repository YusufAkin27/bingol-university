package edu.bingol.backend.forum.profile;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.export.DataExporter;
import edu.bingol.backend.forum.ForumTestDb;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

/** KVKK disa aktarim: yalniz kullanicinin KENDI verisi (anonim paylasimlar dahil), baskasininki yok, bolum adi "forum". */
class ForumDataExporterTest {

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> list(Map<String, Object> m, String key) {
        return (List<Map<String, Object>>) m.get(key);
    }

    @Test
    void exportsOnlyOwnDataIncludingAnonymousOnes() {
        JdbcTemplate j = ForumTestDb.create();
        ForumTestDb.topic(j, 10, 1, false, "Acik", "gövde", "ACTIVE", false, "2026-11-01 10:00:00");
        ForumTestDb.topic(j, 11, 1, true, "Anonim", "gizli", "ACTIVE", false, "2026-11-01 11:00:00");
        ForumTestDb.topic(j, 12, 1, false, "Silinmis", "x", "ACTIVE", true, "2026-11-01 12:00:00");
        ForumTestDb.topic(j, 20, 2, false, "Baskasi", "x", "ACTIVE", false, "2026-11-01 13:00:00");
        ForumTestDb.comment(j, 30, 20, 1, true, "anonim yorumum", "ACTIVE", false, "2026-11-02 10:00:00");
        ForumTestDb.comment(j, 31, 10, 2, false, "baskasinin yorumu", "ACTIVE", false, "2026-11-02 11:00:00");
        j.update("INSERT INTO forum_topic_like (topic_id, user_id) VALUES (20, 1), (10, 2)");
        j.update("INSERT INTO forum_comment_like (comment_id, user_id) VALUES (31, 1)");
        j.update("INSERT INTO forum_bookmark (user_id, target_type, target_id) VALUES (1, 'TOPIC', 20), (2, 'TOPIC', 10)");
        j.update("INSERT INTO forum_topic_follow (topic_id, user_id, notify, follow) VALUES (20, 1, FALSE, TRUE)");
        j.update("INSERT INTO forum_poll_vote (poll_id, user_id, option_id) VALUES (3, 1, 8), (3, 2, 9)");
        j.update("INSERT INTO forum_user_mute (user_id, muted_user_id) VALUES (1, 2), (2, 1)");
        j.update("INSERT INTO forum_anon_alias (topic_id, user_id, n) VALUES (20, 1, 3), (20, 2, 4)");
        j.update("INSERT INTO forum_notification_pref (user_id, likes) VALUES (1, FALSE)");

        Map<String, Object> out = ForumDataExporter.export(j, 1L);

        assertEquals(List.of(11L, 10L), list(out, "topics").stream().map(r -> ((Number) r.get("id")).longValue()).toList());
        assertTrue(list(out, "topics").stream().anyMatch(r -> Boolean.TRUE.equals(r.get("anonymous"))));
        assertEquals(1, list(out, "comments").size());
        assertEquals("anonim yorumum", String.valueOf(list(out, "comments").get(0).get("body")));
        assertEquals(1, list(out, "topicLikes").size());
        assertEquals(1, list(out, "commentLikes").size());
        assertEquals(1, list(out, "bookmarks").size());
        assertEquals(1, list(out, "follows").size());
        assertEquals(1, list(out, "pollVotes").size());
        assertEquals(1, list(out, "mutedUsers").size());
        assertEquals(1, list(out, "anonymousAliases").size());
        assertEquals(3, ((Number) list(out, "anonymousAliases").get(0).get("number")).intValue());
        assertEquals(Boolean.FALSE, list(out, "notificationSettings").get(0).get("likes"));
        // baskasinin yorum metni / kimligi yok
        assertFalse(out.toString().contains("baskasinin yorumu"));
    }

    @Test
    void missingTableDoesNotBreakTheWholeExport() {
        JdbcTemplate j = ForumTestDb.create();
        j.execute("DROP TABLE forum_poll_vote");
        Map<String, Object> out = ForumDataExporter.export(j, 1L);
        assertTrue(list(out, "pollVotes").isEmpty());
        assertTrue(out.containsKey("topics"));
    }

    @Test
    void sectionNameIsForum() {
        DataExporter e = new ForumDataExporter().forumExporter(ForumTestDb.create());
        assertEquals("forum", e.section());
    }
}
