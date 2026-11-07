package edu.bingol.backend.post.feed;

import java.time.Duration;
import java.util.Collection;
import java.util.List;

/**
 * Kullanıcı başına "görülmüş gönderi" kümesinin depolaması (kısa ömürlü teknik veri). Üretimde Redis
 * ({@link RedisFeedSeenStore}), testlerde bellek ({@link InMemoryFeedSeenStore}); seçim `app.feed.seen-store`.
 * Skor = görülme damgası (milisaniye x 1000 + sıra); küçükten büyüğe eskiden yeniye.
 */
public interface FeedSeenStore {

    /** Görülmüş kimlik + damga. */
    record Entry(long postId, long stamp) {}

    /** Kimlikleri ekler/günceller; en çok `max` öğe (en eskiler atılır); anahtar ömrü `ttl` yenilenir. */
    void add(long userId, Collection<Long> postIds, long baseStamp, int max, Duration ttl);

    /** Tüm kümeyi eskiden yeniye döndürür (en çok `max` öğe). */
    List<Entry> all(long userId);

    /** (afterExclusive, beforeExclusive) damga aralığı, eskiden yeniye, en çok `limit` öğe. */
    List<Entry> range(long userId, long afterExclusive, long beforeExclusive, int limit);

    /** Oturum kümesi (Reels): anahtara kimlik ekler, anahtar ömrü `ttl`. */
    void sessionAdd(String key, Collection<Long> postIds, Duration ttl);

    /** Oturum kümesindeki kimlikler. */
    java.util.Set<Long> sessionIds(String key);

    /** Hesap silme / sıfırlama. */
    void delete(long userId);

    /** Tek seferlik talep (SET NX PX): true = ilk kez alındı. Anahtar `ttl` sonra düşer. */
    boolean claim(String key, Duration ttl);
}
