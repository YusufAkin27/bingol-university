package edu.bingol.backend.forum.topic.spi;

/**
 * SPI (uygulayan: forum.topic, A): konunun moderasyon durum alanlari. Yetki karari ve denetim kaydi CAGIRANDADIR
 * (D: forum.moderation); burada yalniz durum degisir. Hepsi idempotenttir. Konu yoksa/silinmisse 404 FORUM_TOPIC_NOT_FOUND.
 */
public interface ForumTopicStateService {

    /** Sabitle (pinned_at = simdi); zaten sabitse degismez. */
    TopicRef pin(Long topicId);

    TopicRef unpin(Long topicId);

    /** Yorumlari kilitle (locked_at = simdi). */
    TopicRef lock(Long topicId);

    TopicRef unlock(Long topicId);

    /** Moderasyonla kaldir (status = REMOVED, gerekce saklanir); listelerden, aramadan ve detaydan duser. */
    TopicRef remove(Long topicId, String reason);

    /** Kaldirmayi geri al (status = ACTIVE). */
    TopicRef restore(Long topicId);
}
