package edu.bingol.backend.forum.notify;

import edu.bingol.backend.forum.topic.spi.ForumTopicFollowLookup;
import edu.bingol.backend.i18n.Lang;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * {@link ForumNotifyReader} uretim uygulamasi: sozlesmedeki tablo/sutun adlariyla duz SQL (forum paketleri arasi
 * Java bagimliligi kurmamak icin; bkz. FORUM_API.md 0 "Entity'ler arasi JPA iliskisi KURMA").
 */
@Component
public class JdbcForumNotifyReader implements ForumNotifyReader {

    private final JdbcTemplate jdbc;
    /** Konu takibi/bildirim tercihi: A'nin SPI'si (varsa); yoksa ayni anlamli duz SQL. */
    private final ObjectProvider<ForumTopicFollowLookup> follows;

    public JdbcForumNotifyReader(JdbcTemplate jdbc, ObjectProvider<ForumTopicFollowLookup> follows) {
        this.jdbc = jdbc;
        this.follows = follows;
    }

    @Override
    public Optional<TopicInfo> topic(long topicId) {
        return jdbc.query("SELECT id, user_id, anonymous, title, category_id, status, deleted_at FROM forum_topic WHERE id = ?",
                (rs, i) -> new TopicInfo(rs.getLong("id"), rs.getLong("user_id"), rs.getBoolean("anonymous"),
                        rs.getString("title"), rs.getLong("category_id"),
                        "ACTIVE".equals(rs.getString("status")) && rs.getTimestamp("deleted_at") == null),
                topicId).stream().findFirst();
    }

    @Override
    public Optional<CommentInfo> comment(long commentId) {
        return jdbc.query("""
                SELECT c.id, c.topic_id, c.user_id, c.anonymous, c.parent_comment_id, c.body, c.status, c.deleted_at,
                       p.user_id AS parent_user_id
                FROM forum_comment c LEFT JOIN forum_comment p ON p.id = c.parent_comment_id
                WHERE c.id = ?""",
                (rs, i) -> {
                    long parent = rs.getLong("parent_comment_id");
                    boolean hasParent = !rs.wasNull();
                    long parentUser = rs.getLong("parent_user_id");
                    boolean hasParentUser = !rs.wasNull();
                    return new CommentInfo(rs.getLong("id"), rs.getLong("topic_id"), rs.getLong("user_id"),
                            rs.getBoolean("anonymous"), hasParent ? parent : null, hasParentUser ? parentUser : null,
                            rs.getString("body"),
                            "ACTIVE".equals(rs.getString("status")) && rs.getTimestamp("deleted_at") == null);
                }, commentId).stream().findFirst();
    }

    @Override
    public String categoryName(long categoryId, Lang lang) {
        String col = switch (lang) {
            case EN -> "name_en";
            case AR -> "name_ar";
            default -> "name_tr";
        };
        List<String> r = jdbc.query("SELECT " + col + " AS n, name_tr FROM forum_category WHERE id = ?",
                (rs, i) -> {
                    String v = rs.getString("n");
                    return v == null || v.isBlank() ? rs.getString("name_tr") : v;
                }, categoryId);
        return r.isEmpty() ? null : r.get(0);
    }

    @Override
    public Integer anonAlias(long topicId, long userId) {
        List<Integer> r = jdbc.query("SELECT n FROM forum_anon_alias WHERE topic_id = ? AND user_id = ?",
                (rs, i) -> rs.getInt("n"), topicId, userId);
        return r.isEmpty() ? null : r.get(0);
    }

    @Override
    public boolean topicNotificationsOff(long topicId, long userId) {
        ForumTopicFollowLookup spi = follows.getIfAvailable();
        if (spi != null) {
            return !spi.notificationsEnabled(topicId, userId);
        }
        Integer n = jdbc.queryForObject(
                "SELECT COUNT(*) FROM forum_topic_follow WHERE topic_id = ? AND user_id = ? AND notify = FALSE",
                Integer.class, topicId, userId);
        return n != null && n > 0;
    }

    @Override
    public List<Long> notifyingFollowers(long topicId, int limit) {
        ForumTopicFollowLookup spi = follows.getIfAvailable();
        if (spi != null) {
            return spi.notifyFollowers(topicId, limit).stream().sorted().limit(limit).toList();
        }
        return jdbc.queryForList("""
                SELECT user_id FROM forum_topic_follow WHERE topic_id = ? AND follow = TRUE AND notify = TRUE
                ORDER BY user_id LIMIT ?""", Long.class, topicId, limit);
    }

    @Override
    public boolean muted(long muterId, long mutedId) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM forum_user_mute WHERE user_id = ? AND muted_user_id = ?",
                Integer.class, muterId, mutedId);
        return n != null && n > 0;
    }

    @Override
    public Set<Long> mutersAmong(Collection<Long> muterIds, long mutedId) {
        if (muterIds == null || muterIds.isEmpty()) {
            return Set.of();
        }
        String in = String.join(",", java.util.Collections.nCopies(muterIds.size(), "?"));
        List<Object> args = new java.util.ArrayList<>(muterIds);
        args.add(mutedId);
        return new java.util.HashSet<>(jdbc.queryForList(
                "SELECT user_id FROM forum_user_mute WHERE user_id IN (" + in + ") AND muted_user_id = ?", Long.class,
                args.toArray()));
    }

    @Override
    public boolean topicHasImage(long topicId) {
        Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM forum_topic_image WHERE topic_id = ?", Integer.class,
                topicId);
        return n != null && n > 0;
    }
}
