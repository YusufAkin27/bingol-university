package edu.bingol.backend.forum.comment;

import java.time.Instant;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Forum yorum sayaclari: YALNIZ atomik UPDATE (okuma-degistir-yaz yok), asla negatife dusmez. Anlamlar:
 * <ul>
 *   <li>forum_topic.comment_count = konudaki CANLI yorum sayisi (yanitlar dahil, yer tutucular HARIC);</li>
 *   <li>forum_comment.reply_count = dogrudan "listelenen" cocuk sayisi (canli, ya da kendi altinda listelenen cocugu olan yer tutucu);</li>
 *   <li>forum_comment.like_count = begeni sayisi.</li>
 * </ul>
 * Kilit sirasi (kilitlenme olmasin): once yorum satiri (alttan uste, atalara dogru), EN SON forum_topic satiri.
 */
@Component
class ForumCommentCounters {

    private final JdbcTemplate jdbc;
    private final ForumCommentStore store;

    ForumCommentCounters(JdbcTemplate jdbc, ForumCommentStore store) {
        this.jdbc = jdbc;
        this.store = store;
    }

    /** Konu yorum sayaci; yeni yorumda (activity=true) son etkinlik zamani da ilerler. */
    void topicComments(long topicId, int delta, boolean activity) {
        if (activity) {
            jdbc.update("UPDATE forum_topic SET comment_count = GREATEST(comment_count + ?, 0), last_activity_at = ? "
                    + "WHERE id = ?", delta, java.sql.Timestamp.from(Instant.now()), topicId);
        } else {
            jdbc.update("UPDATE forum_topic SET comment_count = GREATEST(comment_count + ?, 0) WHERE id = ?", delta, topicId);
        }
    }

    void replies(long commentId, int delta) {
        jdbc.update("UPDATE forum_comment SET reply_count = GREATEST(reply_count + ?, 0) WHERE id = ?", delta, commentId);
    }

    void likes(long commentId, int delta) {
        jdbc.update("UPDATE forum_comment SET like_count = GREATEST(like_count + ?, 0) WHERE id = ?", delta, commentId);
    }

    /**
     * Bir yorum listelerden CIKTI (yer tutucu olup altinda yaniti yok ya da kaldirildi/silindi ve yanitsiz): ust yorumun
     * reply_count'u duser; ust de yer tutucuysa ve artik listelenen cocugu kalmadiysa o da listeden cikar (yukari zincir).
     */
    void unlisted(ForumCommentRow c) {
        Long p = c.parentId();
        int guard = 0;
        while (p != null && guard++ < 100_000) {
            replies(p, -1);
            ForumCommentRow pr = store.find(p).orElse(null);
            if (pr == null || pr.live() || pr.replyCount() > 0) {
                return;
            }
            p = pr.parentId();
        }
    }

    /** {@link #unlisted}'in tersi: yer tutucu yeniden listelendi (geri alma / canli yorum). */
    void relisted(ForumCommentRow c) {
        Long p = c.parentId();
        int guard = 0;
        while (p != null && guard++ < 100_000) {
            replies(p, 1);
            ForumCommentRow pr = store.find(p).orElse(null);
            // Artis sonrasi 1 ise ust yer tutucu daha once listelenmiyordu: o da listeye girdi, yukari devam
            if (pr == null || pr.live() || pr.replyCount() > 1) {
                return;
            }
            p = pr.parentId();
        }
    }

}
