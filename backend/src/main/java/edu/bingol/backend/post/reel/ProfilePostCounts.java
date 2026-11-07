package edu.bingol.backend.post.reel;

import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Profil sayaclari: bir kullanicinin GORUNUR gonderi sayisi (silinmemis, gizlenmemis, en az bir gorunur medya) ve bunlarin
 * video olanlari (Reels). Bakandan bagimsiz herkese acik sayi; gizli hesap/golge engel kararini cagiran verir.
 * Duz SQL (H2 + PostgreSQL ortak).
 */
@Component
public class ProfilePostCounts {

    public record Counts(long postCount, long reelCount) {}

    private static final String BASE = "SELECT COUNT(*) FROM post p WHERE p.author_id = ? AND p.deleted_at IS NULL "
            + "AND p.hidden_at IS NULL AND EXISTS (SELECT 1 FROM post_media m WHERE m.post_id = p.id AND m.hidden_at IS NULL";

    private final JdbcTemplate jdbc;

    public ProfilePostCounts(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Counts counts(Long userId) {
        return new Counts(count(BASE + ")", userId), count(BASE + " AND m.kind = 'VIDEO')", userId));
    }

    private long count(String sql, Long userId) {
        List<Long> r = jdbc.queryForList(sql, Long.class, userId);
        return r.isEmpty() || r.get(0) == null ? 0 : r.get(0);
    }
}
