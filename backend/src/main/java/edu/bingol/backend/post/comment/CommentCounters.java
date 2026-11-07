package edu.bingol.backend.post.comment;

import java.util.Collection;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Yorum sayaclari icin atomik SQL (negatife dusmez) ve yeniden sayim. Gunluk akis artir/azalt ile tutulur (yaris
 * durumsuz); yonetici gizleme, hesap silme ve gece onarimi dogrudan yeniden sayar. Standart SQL (H2 + PostgreSQL).
 */
@Component
public class CommentCounters {

    /** Gonderideki gorunur yorum + yanit sayisi: silinmemis, gizlenmemis ve (yanitsa) ust yorumu da gorunur olanlar. */
    static final String VISIBLE_COUNT = "(SELECT COUNT(*) FROM post_comment c WHERE c.post_id = p.id AND c.deleted_at IS NULL "
            + "AND c.hidden_at IS NULL AND (c.parent_id IS NULL OR EXISTS (SELECT 1 FROM post_comment pc WHERE pc.id = c.parent_id "
            + "AND pc.deleted_at IS NULL AND pc.hidden_at IS NULL)))";

    static final String VISIBLE_REPLIES = "(SELECT COUNT(*) FROM post_comment r WHERE r.parent_id = c.id "
            + "AND r.deleted_at IS NULL AND r.hidden_at IS NULL)";

    private final JdbcTemplate jdbc;

    public CommentCounters(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void addToPost(long postId, int delta) {
        jdbc.update("UPDATE post SET comment_count = GREATEST(comment_count + ?, 0) WHERE id = ?", delta, postId);
    }

    public void addReplies(long commentId, int delta) {
        jdbc.update("UPDATE post_comment SET reply_count = GREATEST(reply_count + ?, 0) WHERE id = ?", delta, commentId);
    }

    public void addLikes(long commentId, int delta) {
        jdbc.update("UPDATE post_comment SET like_count = GREATEST(like_count + ?, 0) WHERE id = ?", delta, commentId);
    }

    public int likeCount(long commentId) {
        Integer n = jdbc.queryForObject("SELECT like_count FROM post_comment WHERE id = ?", Integer.class, commentId);
        return n == null ? 0 : n;
    }

    /** Verilen gonderilerin yorum sayisini ve onlardaki ust yorumlarin yanit sayisini yeniden hesaplar. */
    public void recountPosts(Collection<Long> postIds) {
        if (postIds == null || postIds.isEmpty()) {
            return;
        }
        NamedParameterJdbcTemplate named = new NamedParameterJdbcTemplate(jdbc);
        MapSqlParameterSource ids = new MapSqlParameterSource("ids", postIds);
        named.update("UPDATE post_comment AS c SET reply_count = " + VISIBLE_REPLIES
                + " WHERE c.parent_id IS NULL AND c.post_id IN (:ids)", ids);
        named.update("UPDATE post AS p SET comment_count = " + VISIBLE_COUNT + " WHERE p.id IN (:ids)", ids);
    }

    /**
     * Gece onarimi: sayaci gercekten sapmis gonderi/yorumlari duzeltir.
     * @return duzeltilen satir sayisi
     */
    public int repairAll() {
        int replies = jdbc.update("UPDATE post_comment AS c SET reply_count = " + VISIBLE_REPLIES
                + " WHERE c.parent_id IS NULL AND c.reply_count <> " + VISIBLE_REPLIES);
        int posts = jdbc.update("UPDATE post AS p SET comment_count = " + VISIBLE_COUNT
                + " WHERE p.comment_count <> " + VISIBLE_COUNT);
        int likes = jdbc.update("UPDATE post_comment AS c SET like_count = (SELECT COUNT(*) FROM post_comment_like l "
                + "WHERE l.comment_id = c.id) WHERE c.like_count <> (SELECT COUNT(*) FROM post_comment_like l "
                + "WHERE l.comment_id = c.id)");
        return replies + posts + likes;
    }
}
