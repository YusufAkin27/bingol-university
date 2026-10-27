package edu.bingol.backend.post.admin;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * KVKK disa aktarim: kullanicinin Kesfet gonderileri (medya yalniz meta), yorumlari ve begenileri. Yalniz kendi
 * verisi; baskasinin kisisel verisi yoktur (begeni: gonderi kimligi + zaman; yorum: kendi metni).
 */
@Configuration
public class PostExporters {

    /** Disa aktarimda kullanicinin gonderi/yorum sayisi ust siniri (bellek korumasi). */
    static final int MAX_ROWS = 5000;

    @Bean
    DataExporter postsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("posts", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList("SELECT id, body AS text, like_count AS \"likeCount\", "
                    + "comment_count AS \"commentCount\", media_count AS \"mediaCount\", CAST(created_at AS varchar) AS \"createdAt\", "
                    + "CAST(edited_at AS varchar) AS \"editedAt\", CAST(deleted_at AS varchar) AS \"deletedAt\", "
                    + "CAST(hidden_at AS varchar) AS \"hiddenAt\" FROM post WHERE author_id = ? ORDER BY id DESC LIMIT " + MAX_ROWS, uid);
            List<Map<String, Object>> media = jdbc.queryForList("SELECT id, post_id AS \"postId\", kind, content_type AS \"contentType\", "
                    + "width, height, duration_ms AS \"durationMs\", bytes, CAST(created_at AS varchar) AS \"createdAt\" "
                    + "FROM post_media WHERE owner_id = ? ORDER BY id DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("count", rows.size(), "posts", rows, "mediaMeta", media);
        });
    }

    @Bean
    DataExporter postCommentsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("postComments", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList("SELECT id, post_id AS \"postId\", parent_id AS \"parentId\", "
                    + "body AS text, CAST(created_at AS varchar) AS \"createdAt\", CAST(edited_at AS varchar) AS \"editedAt\", "
                    + "CAST(deleted_at AS varchar) AS \"deletedAt\" FROM post_comment WHERE author_id = ? ORDER BY id DESC LIMIT "
                    + MAX_ROWS, uid);
            return Map.of("count", rows.size(), "comments", rows);
        });
    }

    @Bean
    DataExporter postLikesExporter(JdbcTemplate jdbc) {
        return DataExporter.of("postLikes", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList("SELECT post_id AS \"postId\", CAST(created_at AS varchar) AS \"likedAt\" "
                    + "FROM post_like WHERE user_id = ? ORDER BY created_at DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("count", rows.size(), "likes", rows);
        });
    }
}
