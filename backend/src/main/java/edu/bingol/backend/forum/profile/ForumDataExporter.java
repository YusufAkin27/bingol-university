package edu.bingol.backend.forum.profile;

import edu.bingol.backend.export.DataExporter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * KVKK "verilerimi indir": forum bolumu (kullanicinin KENDI verisi; anonim paylasimlari da kendi verisi oldugundan
 * dahildir). Baskalarinin kisisel verisi yoktur: yalniz kendi konu/yorum metinleri, kendi beğeni/kayit/takip/anket
 * oyu/sessize alma/tercih satirlari ve kendi anonim takma ad numaralari. Bolum adi {@code forum}.
 *
 * <p>Her alt liste ayri sorgudur ve ayri korunur: bir alt tablodaki hata dizisi bos birakir ve loglanir (butun
 * disa aktarimi dusurmez), ama sessiz de gecilmez (uyari).
 */
@Configuration
public class ForumDataExporter {

    private static final Logger log = LoggerFactory.getLogger(ForumDataExporter.class);
    /** Bir alt listede en cok satir (sinirsiz sorgu yok). */
    static final int MAX_ROWS = 5000;

    @Bean
    DataExporter forumExporter(JdbcTemplate jdbc) {
        return DataExporter.of("forum", userId -> export(jdbc, userId));
    }

    static Map<String, Object> export(JdbcTemplate jdbc, Long userId) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("topics", rows(jdbc, "topics", """
                SELECT id, category_id AS categoryId, title, body, anonymous, status, created_at AS createdAt,
                       edited_at AS editedAt
                  FROM forum_topic WHERE user_id = ? AND deleted_at IS NULL ORDER BY id DESC LIMIT ?""", userId));
        out.put("comments", rows(jdbc, "comments", """
                SELECT id, topic_id AS topicId, parent_comment_id AS parentCommentId, body, anonymous, status,
                       created_at AS createdAt, edited_at AS editedAt
                  FROM forum_comment WHERE user_id = ? AND deleted_at IS NULL ORDER BY id DESC LIMIT ?""", userId));
        out.put("topicLikes", rows(jdbc, "topicLikes",
                "SELECT topic_id AS topicId, created_at AS createdAt FROM forum_topic_like WHERE user_id = ? "
                        + "ORDER BY created_at DESC LIMIT ?", userId));
        out.put("commentLikes", rows(jdbc, "commentLikes",
                "SELECT comment_id AS commentId, created_at AS createdAt FROM forum_comment_like WHERE user_id = ? "
                        + "ORDER BY created_at DESC LIMIT ?", userId));
        out.put("bookmarks", rows(jdbc, "bookmarks",
                "SELECT target_type AS targetType, target_id AS targetId, created_at AS createdAt FROM forum_bookmark "
                        + "WHERE user_id = ? ORDER BY created_at DESC LIMIT ?", userId));
        out.put("follows", rows(jdbc, "follows",
                "SELECT topic_id AS topicId, follow, notify, created_at AS createdAt FROM forum_topic_follow "
                        + "WHERE user_id = ? ORDER BY created_at DESC LIMIT ?", userId));
        out.put("pollVotes", rows(jdbc, "pollVotes",
                "SELECT poll_id AS pollId, option_id AS optionId, created_at AS createdAt FROM forum_poll_vote "
                        + "WHERE user_id = ? ORDER BY created_at DESC LIMIT ?", userId));
        out.put("mutedUsers", rows(jdbc, "mutedUsers",
                "SELECT muted_user_id AS userId, created_at AS createdAt FROM forum_user_mute WHERE user_id = ? "
                        + "ORDER BY created_at DESC LIMIT ?", userId));
        out.put("anonymousAliases", rows(jdbc, "anonymousAliases",
                "SELECT topic_id AS topicId, n AS number FROM forum_anon_alias WHERE user_id = ? "
                        + "ORDER BY topic_id DESC LIMIT ?", userId));
        out.put("notificationSettings", rows(jdbc, "notificationSettings", """
                SELECT all_enabled AS allEnabled, topic_comments AS topicComments, comment_replies AS commentReplies,
                       likes, followed_topics AS followedTopics, moderation, updated_at AS updatedAt
                  FROM forum_notification_pref WHERE user_id = ? LIMIT ?""", userId));
        return out;
    }

    private static List<Map<String, Object>> rows(JdbcTemplate jdbc, String name, String sql, Long userId) {
        try {
            return jdbc.queryForList(sql, userId, MAX_ROWS);
        } catch (RuntimeException e) {
            log.warn("Forum veri disa aktarimi: '{}' bolumu okunamadi: {}", name, e.toString());
            return List.of();
        }
    }
}
