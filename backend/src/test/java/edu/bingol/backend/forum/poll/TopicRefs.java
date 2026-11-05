package edu.bingol.backend.forum.poll;

import edu.bingol.backend.forum.topic.spi.TopicRef;

/** Test yardimcisi: TopicRef kurucusunu tek yerde toplar (A alaninin sozlesmesi degisirse yalniz burasi guncellenir). */
final class TopicRefs {

    private TopicRefs() {}

    static TopicRef of(long topicId, boolean locked, String status) {
        return new TopicRef(topicId, 1L, false, locked, 1L, TopicRef.Status.valueOf(status));
    }
}
