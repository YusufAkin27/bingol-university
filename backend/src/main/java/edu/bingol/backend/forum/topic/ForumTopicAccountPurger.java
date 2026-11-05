package edu.bingol.backend.forum.topic;

import edu.bingol.backend.forum.media.ForumMediaService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Hesap silme (KVKK), forum konu verisi (A alani tablolari): gorseller + baytlar, begeniler (+ sayaclar), kayitlar,
 * takipler ve anonim takma adlar silinir; kullanicinin konulari yumusak silinir ve basligi/govdesi temizlenir
 * (baskalarinin yorumlari konunun baglamini tasir, ama icerik kimliksiz kalir). AccountDataPurger.purge cagirir.
 * Yorum/anket/bildirim tablolari B/C/E alanlaridir ve kendi temizleyicilerinde ele alinir.
 */
@Component
public class ForumTopicAccountPurger {

    private final ForumMediaService media;
    private final ForumReactionService reactions;
    private final ForumBookmarkService bookmarks;
    private final JdbcTemplate jdbc;

    public ForumTopicAccountPurger(ForumMediaService media, ForumReactionService reactions,
                                   ForumBookmarkService bookmarks, JdbcTemplate jdbc) {
        this.media = media;
        this.reactions = reactions;
        this.bookmarks = bookmarks;
        this.jdbc = jdbc;
    }

    @Transactional
    public void purge(Long userId) {
        reactions.purgeUser(userId);
        bookmarks.purgeUser(userId);
        jdbc.update("DELETE FROM forum_anon_alias WHERE user_id = ?", userId);
        jdbc.update("UPDATE forum_topic SET title = '[silindi]', body = '[silindi]', pinned_at = NULL, "
                + "deleted_at = COALESCE(deleted_at, CURRENT_TIMESTAMP) WHERE user_id = ?", userId);
        media.purgeUser(userId);
    }
}
