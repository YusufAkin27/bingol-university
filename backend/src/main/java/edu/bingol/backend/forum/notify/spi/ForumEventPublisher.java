package edu.bingol.backend.forum.notify.spi;

/**
 * SPI: forum olaylari. Arayuzu A yayinlar, UYGULAYAN E'dir (forum.notify); A/B/C/D olay olunca bunu cagirir.
 * Cagiranlar bean'i {@code ObjectProvider<ForumEventPublisher>} ile alip yoksa atlar. Uygulama kendi hatasini
 * cagirana SIZDIRMAZ. Kendine bildirim, tekrar, tercih ve engel kurallari uygulayicidadir (E).
 */
public interface ForumEventPublisher {

    /** Hedef turu (bildirim yuku {@code targetType}: FORUM_TOPIC / FORUM_COMMENT). */
    enum TargetType { TOPIC, COMMENT }

    /** Konu begenildi (yalniz yeni begeni; geri alma ve cift PUT olay uretmez). */
    void topicLiked(Long topicId, Long actorId);

    /** Yorum olustu (B cagirir): konu sahibine, ust yorumun sahibine ve konu takipcilerine gider. */
    void commentCreated(Long commentId, Long actorId);

    /** Yorum begenildi (B cagirir; yalniz yeni begeni). */
    void commentLiked(Long commentId, Long actorId);

    /**
     * Moderator islemi (D cagirir): icerik sahibine gerekce metniyle.
     *
     * @param action PIN, UNPIN, LOCK, UNLOCK, REMOVE, RESTORE
     */
    void moderationAction(TargetType targetType, Long targetId, String action, String reason);
}
