package edu.bingol.backend.forum.moderation;

/**
 * Moderasyon alaninin A (konu) ve B (yorum) durum servislerine ve E (bildirim) olay arayuzune acilan TEK kapisi.
 * Tum cagrilar idempotent olmali (zaten o durumdaysa sessizce basarili). Gercek uygulama {@link ForumStateAdapter}'dir;
 * testler sahte uygulama verir.
 */
public interface ForumStatePort {

    void pinTopic(Long topicId);

    void unpinTopic(Long topicId);

    void lockTopic(Long topicId);

    void unlockTopic(Long topicId);

    void removeTopic(Long topicId, String reason);

    void restoreTopic(Long topicId);

    void removeComment(Long commentId, String reason);

    void restoreComment(Long commentId);

    /**
     * Icerik sahibine "moderator islemi" bildirimi (E). Bildirim sistemi yoksa/hata verirse sessizce atlanir (islem
     * geri alinmaz).
     *
     * @param targetType TOPIC | COMMENT
     */
    void publishModeration(String targetType, Long targetId, Long topicId, String action, String reason);
}
