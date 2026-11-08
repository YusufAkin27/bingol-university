package edu.bingol.backend.post;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/** Gonderi sayaclari icin atomik SQL (yaris durumsuz). Negatife dusmez. begeni servisi cagirir. */
@Component
public class PostCounters {

    private final JdbcTemplate jdbc;

    public PostCounters(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void incrementLikes(long postId, int delta) {
        jdbc.update("UPDATE post SET like_count = GREATEST(like_count + ?, 0) WHERE id = ?", delta, postId);
    }

    /** Bir izlenme sayar; pct = bu izlenmenin tamamlanma yuzdesi (0..100). */
    public void addView(long postId, int pct) {
        jdbc.update("UPDATE post SET view_count = view_count + 1, completion_pct_sum = completion_pct_sum + ? WHERE id = ?",
                Math.max(0, Math.min(100, pct)), postId);
    }

    /** Guncel begeni sayisi (yanit icin). */
    public int likeCount(long postId) {
        Integer n = jdbc.queryForObject("SELECT like_count + like_boost FROM post WHERE id = ?", Integer.class, postId);
        return n == null ? 0 : n;
    }
}
