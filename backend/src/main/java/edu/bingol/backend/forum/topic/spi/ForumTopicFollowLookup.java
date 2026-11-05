package edu.bingol.backend.forum.topic.spi;

import java.util.Set;

/**
 * SPI (uygulayan: forum.topic, A): konu takibi ve bildirim tercihi (E bildirim hedeflerini buradan secer;
 * tabloya dogrudan bakmaz).
 */
public interface ForumTopicFollowLookup {

    /** Konuyu takip eden VE bildirimi acik kullanicilar (en cok {@code limit}; kimlik sirali). */
    Set<Long> notifyFollowers(Long topicId, int limit);

    /**
     * Kullanicinin bu konunun bildirimlerini alip almadigi (varsayilan true). Konu sahibi dahil herkes icin
     * "bildirimleri kapat" tercihi false doner.
     */
    boolean notificationsEnabled(Long topicId, Long userId);
}
