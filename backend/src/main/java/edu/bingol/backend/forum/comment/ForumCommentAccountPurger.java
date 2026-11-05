package edu.bingol.backend.forum.comment;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Hesap silmede (KVKK) forum yorumlari: begeniler silinir (yorumlarin begeni sayaci duser); kullanicinin yorumlari
 * mezar tasi olur (govde "[silindi]", satir iz olarak kalir; altinda yanit varsa yer tutucu, yoksa listeden cikar) ve
 * konu/ust yorum sayaclari duzelir. AccountDataPurger.purge cagirir (cagirani islemine katilir).
 */
@Component
public class ForumCommentAccountPurger {

    private final JdbcTemplate jdbc;
    private final ForumCommentLifecycle lifecycle;
    private final TransactionTemplate tx;

    ForumCommentAccountPurger(JdbcTemplate jdbc, ForumCommentLifecycle lifecycle, PlatformTransactionManager tm) {
        this.jdbc = jdbc;
        this.lifecycle = lifecycle;
        this.tx = new TransactionTemplate(tm);
    }

    public void purge(Long userId) {
        tx.executeWithoutResult(st -> {
            jdbc.update("UPDATE forum_comment SET like_count = GREATEST(like_count - 1, 0) "
                    + "WHERE id IN (SELECT comment_id FROM forum_comment_like WHERE user_id = ?)", userId);
            jdbc.update("DELETE FROM forum_comment_like WHERE user_id = ?", userId);
            lifecycle.purgeUserComments(userId);
        });
    }
}
