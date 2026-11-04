package edu.bingol.backend.post.comment;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * KVKK disa aktarim (KS-BE2): kullanicinin kendi yorumlari (metin dahil; silinenlerin metni zaten temizdir), yorum
 * begenileri ve kaydettigi gonderiler. Yalniz kendi verisi: baskasinin kisisel verisi yoktur (kimlikler ve zamanlar).
 */
@Configuration
public class CommentExporters {

    static final int MAX_ROWS = 5000;

    @Bean
    DataExporter postCommentsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("postComments", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList("SELECT id, post_id AS \"postId\", parent_id AS \"parentId\", "
                    + "body AS text, like_count AS \"likeCount\", CAST(created_at AS varchar) AS \"createdAt\", "
                    + "CAST(hidden_at AS varchar) AS \"hiddenAt\", CAST(deleted_at AS varchar) AS \"deletedAt\" "
                    + "FROM post_comment WHERE author_id = ? ORDER BY id DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("count", rows.size(), "comments", rows);
        });
    }

    @Bean
    DataExporter postCommentLikesExporter(JdbcTemplate jdbc) {
        return DataExporter.of("postCommentLikes", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList("SELECT comment_id AS \"commentId\", "
                    + "CAST(created_at AS varchar) AS \"likedAt\" FROM post_comment_like WHERE user_id = ? "
                    + "ORDER BY created_at DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("count", rows.size(), "likes", rows);
        });
    }

    @Bean
    DataExporter postSavesExporter(JdbcTemplate jdbc) {
        return DataExporter.of("postSaves", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList("SELECT post_id AS \"postId\", "
                    + "CAST(created_at AS varchar) AS \"savedAt\" FROM post_save WHERE user_id = ? "
                    + "ORDER BY created_at DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("count", rows.size(), "saves", rows);
        });
    }
}
