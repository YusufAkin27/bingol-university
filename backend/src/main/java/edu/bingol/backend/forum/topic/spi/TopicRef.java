package edu.bingol.backend.forum.topic.spi;

/**
 * Bir forum konusunun diger modullerin (yorum, anket, moderasyon, bildirim...) ihtiyac duydugu hafif gorunumu.
 * Sozlesme: docs/FORUM_API.md "A" alani. {@code authorId} gercek kullanici kimligidir ve ASLA istemciye verilmez;
 * yalniz sunucu ici karar (sahiplik, bildirim hedefi, engel) icindir.
 */
public record TopicRef(Long id, Long authorId, boolean anonymous, boolean locked, Long categoryId, Status status) {

    /** Konu durumu (forum_topic.status). */
    public enum Status { ACTIVE, REMOVED }
}
