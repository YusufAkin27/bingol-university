package edu.bingol.backend.messaging;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * `GET /api/me/summary` okunmamis sohbet rozeti onbellegi (`me:unread:<uid>`, 12 sn). Kullanici okuyunca / sessize
 * alinca / arsivleyince anahtar atilir: aksi halde ana sayfa, az once okunan sohbetin eski sayisini (hayalet rozet)
 * 12 sn boyunca geri getirir ve istemci bunu sohbet sekmesinin dogru degerinin ustune yazar (QA-CHAT-03).
 * Redis yoksa / hata verirse sessizce atlanir (en kotu ihtimal 12 sn eski rozet).
 */
@Component
public class UnreadBadgeCache {

    public static final String KEY_PREFIX = "me:unread:";

    private static final Logger log = LoggerFactory.getLogger(UnreadBadgeCache.class);

    private final StringRedisTemplate redis;

    public UnreadBadgeCache(StringRedisTemplate redis) {
        this.redis = redis;
    }

    public void evict(Long userId) {
        if (userId == null) {
            return;
        }
        try {
            redis.delete(KEY_PREFIX + userId);
        } catch (RuntimeException e) {
            log.debug("Rozet onbellegi atilamadi (kullanici {}): {}", userId, e.toString());
        }
    }
}
