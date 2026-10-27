package edu.bingol.backend.post.social;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * KVKK disa aktarim: kaydedilen gonderiler (kimlik + zaman), takip iliskileri (yalniz kimlikler), kendi
 * hikayeleri (metin/baslik/zaman; baskasinin goruntuleme bilgisi YOK).
 */
@Configuration
public class SocialExporters {

    static final int MAX_ROWS = 5000;

    @Bean
    DataExporter savedPostsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("savedPosts", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList("SELECT post_id AS \"postId\", "
                    + "CAST(created_at AS varchar) AS \"savedAt\" FROM post_save WHERE user_id = ? "
                    + "ORDER BY created_at DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("count", rows.size(), "saved", rows);
        });
    }

    @Bean
    DataExporter followsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("follows", uid -> {
            List<Map<String, Object>> following = jdbc.queryForList("SELECT followee_id AS \"userId\", "
                    + "CAST(created_at AS varchar) AS \"since\" FROM user_follow WHERE follower_id = ? "
                    + "ORDER BY created_at DESC LIMIT " + MAX_ROWS, uid);
            List<Map<String, Object>> followers = jdbc.queryForList("SELECT follower_id AS \"userId\", "
                    + "CAST(created_at AS varchar) AS \"since\" FROM user_follow WHERE followee_id = ? "
                    + "ORDER BY created_at DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("following", following, "followers", followers);
        });
    }

    @Bean
    DataExporter storiesExporter(JdbcTemplate jdbc) {
        return DataExporter.of("stories", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList("SELECT id, kind, body_text AS text, caption, background, "
                    + "view_count AS \"viewCount\", CAST(created_at AS varchar) AS \"createdAt\", "
                    + "CAST(expires_at AS varchar) AS \"expiresAt\" FROM story WHERE author_id = ? AND deleted_at IS NULL "
                    + "ORDER BY id DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("count", rows.size(), "stories", rows);
        });
    }
}
