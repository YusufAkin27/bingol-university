package edu.bingol.backend.post.admin;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * KVKK disa aktarim: kullanicinin Kesfet gonderileri (medya yalniz meta) ve begenileri. Yalniz kendi
 * verisi; baskasinin kisisel verisi yoktur (begeni: gonderi kimligi + zaman; ).
 */
@Configuration
public class PostExporters {

    /** Disa aktarimda kullanicinin gonderi/yorum sayisi ust siniri (bellek korumasi). */
    static final int MAX_ROWS = 5000;

    @Bean
    DataExporter postsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("posts", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList("SELECT id, body AS text, like_count AS \"likeCount\", "
                    + "media_count AS \"mediaCount\", CAST(created_at AS varchar) AS \"createdAt\", "
                    + "CAST(edited_at AS varchar) AS \"editedAt\", CAST(deleted_at AS varchar) AS \"deletedAt\", "
                    + "CAST(hidden_at AS varchar) AS \"hiddenAt\" FROM post WHERE author_id = ? ORDER BY id DESC LIMIT " + MAX_ROWS, uid);
            List<Map<String, Object>> media = jdbc.queryForList("SELECT id, post_id AS \"postId\", kind, content_type AS \"contentType\", "
                    + "width, height, duration_ms AS \"durationMs\", bytes, CAST(created_at AS varchar) AS \"createdAt\" "
                    + "FROM post_media WHERE owner_id = ? ORDER BY id DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("count", rows.size(), "posts", rows, "mediaMeta", media);
        });
    }

    /** Reels izleme geçmişi (45 gün saklanır): kimlik, zaman, sayaçlar, "ilgilenmiyorum". */
    @Bean
    DataExporter postWatchExporter(JdbcTemplate jdbc) {
        return DataExporter.of("reelWatchHistory", uid -> {
            List<Map<String, Object>> rows = jdbc.queryForList("SELECT post_id AS \"postId\", "
                    + "CAST(first_seen_at AS varchar) AS \"firstSeenAt\", CAST(last_seen_at AS varchar) AS \"lastSeenAt\", "
                    + "impressions, watch_ms AS \"watchMs\", completion_pct AS \"completionPct\", skips, "
                    + "not_interested AS \"notInterested\" FROM post_watch WHERE user_id = ? "
                    + "ORDER BY last_seen_at DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("count", rows.size(), "items", rows);
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

    /**
     * Etiketler (V1310): benim etiketlendigim gonderiler (gonderi + yazar kimligi + zaman) ve kendi gonderilerimde
     * etiketledigim kisilerin kimlikleri. Yalniz kimlik ve zaman; baskasinin adi/metni disa aktarilmaz.
     */
    @Bean
    DataExporter postMentionsExporter(JdbcTemplate jdbc) {
        return DataExporter.of("postMentions", uid -> {
            List<Map<String, Object>> taggedIn = jdbc.queryForList("SELECT m.post_id AS \"postId\", p.author_id AS \"authorId\", "
                    + "CAST(m.created_at AS varchar) AS \"taggedAt\" FROM post_mention m JOIN post p ON p.id = m.post_id "
                    + "WHERE m.user_id = ? ORDER BY m.created_at DESC LIMIT " + MAX_ROWS, uid);
            List<Map<String, Object>> tagged = jdbc.queryForList("SELECT m.post_id AS \"postId\", m.user_id AS \"userId\", "
                    + "CAST(m.created_at AS varchar) AS \"taggedAt\" FROM post_mention m JOIN post p ON p.id = m.post_id "
                    + "WHERE p.author_id = ? ORDER BY m.created_at DESC LIMIT " + MAX_ROWS, uid);
            return Map.of("taggedInCount", taggedIn.size(), "taggedIn", taggedIn, "taggedCount", tagged.size(),
                    "tagged", tagged);
        });
    }
}
