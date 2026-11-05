package edu.bingol.backend.forum.moderation;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * A/B durum servislerinin test karsiligi: ayni tablolari duz SQL ile degistirir (gercek servisler kendi sayac ve
 * yan etkilerini yapar; D alani yalniz karar + kayit + olay uretir). Olaylar {@link #events} listesine yazilir.
 */
class FakeForumState implements ForumStatePort {

    record Event(String targetType, Long targetId, Long topicId, String action, String reason) {}

    final List<Event> events = Collections.synchronizedList(new ArrayList<>());
    private final JdbcTemplate jdbc;

    FakeForumState(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public void pinTopic(Long id) {
        jdbc.update("UPDATE forum_topic SET pinned_at = COALESCE(pinned_at, CURRENT_TIMESTAMP) WHERE id = ?", id);
    }

    @Override
    public void unpinTopic(Long id) {
        jdbc.update("UPDATE forum_topic SET pinned_at = NULL WHERE id = ?", id);
    }

    @Override
    public void lockTopic(Long id) {
        jdbc.update("UPDATE forum_topic SET locked_at = COALESCE(locked_at, CURRENT_TIMESTAMP) WHERE id = ?", id);
    }

    @Override
    public void unlockTopic(Long id) {
        jdbc.update("UPDATE forum_topic SET locked_at = NULL WHERE id = ?", id);
    }

    @Override
    public void removeTopic(Long id, String reason) {
        jdbc.update("UPDATE forum_topic SET status = 'REMOVED', removed_reason = ? WHERE id = ?", reason, id);
    }

    @Override
    public void restoreTopic(Long id) {
        jdbc.update("UPDATE forum_topic SET status = 'ACTIVE', removed_reason = NULL WHERE id = ?", id);
    }

    @Override
    public void removeComment(Long id, String reason) {
        jdbc.update("UPDATE forum_comment SET status = 'REMOVED' WHERE id = ?", id);
    }

    @Override
    public void restoreComment(Long id) {
        jdbc.update("UPDATE forum_comment SET status = 'ACTIVE' WHERE id = ?", id);
    }

    @Override
    public void publishModeration(String targetType, Long targetId, Long topicId, String action, String reason) {
        events.add(new Event(targetType, targetId, topicId, action, reason));
    }
}
