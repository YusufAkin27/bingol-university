package edu.bingol.backend.post.spi;

/**
 * Yorum/yanit bildirimleri (C uygular: PostNotifier bu arayuzu gerceklestirir). Hatalar cagirani bozmamalidir;
 * yorum servisi ayrica yakalar. Kendi eylemi icin bildirim gonderilmez (uygulayan eler).
 */
public interface PostNotifierPort {

    /** Kok yorum: gonderi sahibine. */
    void onComment(Long actorId, Long postId, Long postAuthorId, Long commentId);

    /** Yanit: ebeveyn yorum sahibine ve (farkliysa) yanitlanan kullaniciya. */
    void onReply(Long actorId, Long postId, Long commentId, Long parentAuthorId, Long replyToUserId);
}
