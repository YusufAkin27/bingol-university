package edu.bingol.backend.post.comment;

import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hesap silmede (KVKK) yorum/kaydet verisi (KS-BE2): kullanicinin yorum begenileri ve kaydettikleri silinir (sayaclar
 * duser); yazdigi yorum/yanitlarin metni temizlenip yumusak silinir (satir iz olarak kalir, kimlik zaten anonim) ve
 * etkilenen gonderi/yorum sayaclari yeniden hesaplanir. PostAccountPurger.purge cagirir.
 */
@Component
public class CommentAccountPurger {

    private final JdbcTemplate jdbc;
    private final CommentCounters counters;

    public CommentAccountPurger(JdbcTemplate jdbc, CommentCounters counters) {
        this.jdbc = jdbc;
        this.counters = counters;
    }

    public void purge(Long userId) {
        jdbc.update("UPDATE post_comment SET like_count = GREATEST(like_count - 1, 0) "
                + "WHERE id IN (SELECT comment_id FROM post_comment_like WHERE user_id = ?)", userId);
        jdbc.update("DELETE FROM post_comment_like WHERE user_id = ?", userId);
        jdbc.update("DELETE FROM post_save WHERE user_id = ?", userId);
        List<Long> posts = jdbc.queryForList("SELECT DISTINCT post_id FROM post_comment WHERE author_id = ? AND deleted_at IS NULL",
                Long.class, userId);
        jdbc.update("UPDATE post_comment SET deleted_at = CURRENT_TIMESTAMP, deleted_by = ?, body = '' "
                + "WHERE author_id = ? AND deleted_at IS NULL", userId, userId);
        counters.recountPosts(posts);
    }
}
