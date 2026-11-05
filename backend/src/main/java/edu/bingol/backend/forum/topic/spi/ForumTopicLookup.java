package edu.bingol.backend.forum.topic.spi;

import java.util.Optional;

/**
 * SPI (uygulayan: forum.topic, A): diger forum modulleri konuya YALNIZ bu arayuzle bakar.
 * Gorunurluk kurali tek yerdedir: silinmis, moderasyonla kaldirilmis (kimseye, yazarin kendisine bile gorunmez),
 * yazari aktif olmayan (askida/silinmis hesap) ya da bakanla yazar arasinda engel/sessize alma olan konu GORUNMEZDIR.
 */
public interface ForumTopicLookup {

    /**
     * Bakan icin gorunur konu; gorunmez/silinmis/kaldirilmis/engelli ise bos.
     *
     * @param viewerId null olamaz (forum uclari oturum ister); sistem cagrilari icin {@link #topic} kullanin
     */
    Optional<TopicRef> visibleTopic(Long topicId, Long viewerId);

    /**
     * Bakan gozetmeksizin konu (silinmemis; REMOVED dahil). Moderasyon, bildirim ve sayac guncellemeleri icin.
     * Yumusak silinmis konu bos doner.
     */
    Optional<TopicRef> topic(Long topicId);
}
