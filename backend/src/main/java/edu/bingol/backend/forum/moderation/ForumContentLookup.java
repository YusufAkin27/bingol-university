package edu.bingol.backend.forum.moderation;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Moderasyon alaninin forum icerigine SALT OKUNUR bakisi (duz SQL; A/B varliklarina JPA bagi kurulmaz, sozlesme 0).
 * Yazar kimligi ({@code userId}) yalniz sunucu ici kararlar icindir; HICBIR yanita yazilmaz.
 */
@Component
public class ForumContentLookup {

    public record TopicRow(Long id, Long userId, boolean anonymous, String status, boolean deleted, Long categoryId,
                           boolean pinned, boolean locked, String title, String body) {
        public boolean active() {
            return !deleted && "ACTIVE".equals(status);
        }

        public boolean removed() {
            return !deleted && "REMOVED".equals(status);
        }
    }

    public record CommentRow(Long id, Long topicId, Long userId, boolean anonymous, String status, boolean deleted,
                             String body) {
        public boolean active() {
            return !deleted && "ACTIVE".equals(status);
        }

        public boolean removed() {
            return !deleted && "REMOVED".equals(status);
        }
    }

    private final JdbcTemplate jdbc;

    public ForumContentLookup(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<TopicRow> topic(Long id) {
        List<TopicRow> r = jdbc.query("SELECT id, user_id, anonymous, status, deleted_at, category_id, pinned_at, "
                + "locked_at, title, body FROM forum_topic WHERE id = ?",
                (rs, i) -> new TopicRow(rs.getLong(1), rs.getLong(2), rs.getBoolean(3), rs.getString(4),
                        rs.getObject(5) != null, (Long) rs.getObject(6), rs.getObject(7) != null, rs.getObject(8) != null,
                        rs.getString(9), rs.getString(10)), id);
        return r.isEmpty() ? Optional.empty() : Optional.of(r.get(0));
    }

    public Optional<CommentRow> comment(Long id) {
        List<CommentRow> r = jdbc.query("SELECT id, topic_id, user_id, anonymous, status, deleted_at, body "
                + "FROM forum_comment WHERE id = ?",
                (rs, i) -> new CommentRow(rs.getLong(1), rs.getLong(2), rs.getLong(3), rs.getBoolean(4),
                        rs.getString(5), rs.getObject(6) != null, rs.getString(7)), id);
        return r.isEmpty() ? Optional.empty() : Optional.of(r.get(0));
    }

    /** Hesap durumu ACTIVE mi (askidaki/silinmis yazarin icerigi baskalarina gorunmez). */
    public boolean userActive(Long userId) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM app_user WHERE id = ? AND status = 'ACTIVE'", Integer.class, userId);
        return n != null && n > 0;
    }

    /** Konu kategorisinin adi (tr); yoksa null. */
    public String categoryName(Long categoryId) {
        if (categoryId == null) {
            return null;
        }
        List<String> r = jdbc.queryForList("SELECT name_tr FROM forum_category WHERE id = ?", String.class, categoryId);
        return r.isEmpty() ? null : r.get(0);
    }

    static Instant instant(Object ts) {
        return ts instanceof Timestamp t ? t.toInstant() : null;
    }
}
