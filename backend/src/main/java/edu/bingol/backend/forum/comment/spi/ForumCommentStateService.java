package edu.bingol.backend.forum.comment.spi;

/**
 * Yorum durum degisikligi (D moderasyon alani cagirir; B uygular). Yetki karari CAGIRANDA (D: forum.moderate);
 * burada yalnizca durum + sayac tutarliligi vardir. Ikisi de idempotenttir.
 */
public interface ForumCommentStateService {

    /**
     * Yorumu kaldirir (status=REMOVED, govde moderasyon icin saklanir ama API'de gorunmez). Altinda gorunur yaniti varsa
     * `deleted:true` yer tutucu olarak kalir. Zaten kaldirilmis ya da sahibi tarafindan silinmisse bir sey yapmaz.
     * @throws edu.bingol.backend.common.ApiException 404 FORUM_COMMENT_NOT_FOUND
     */
    void remove(Long commentId, String reason);

    /**
     * Moderator kaldirmasini geri alir. Sahibi tarafindan silinmis yorum geri getirilemez (409 FORUM_COMMENT_DELETED);
     * zaten aktif yorumda bir sey yapmaz.
     */
    void restore(Long commentId);
}
