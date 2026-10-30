package edu.bingol.backend.notification;

import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Push yigilmasini onler: ayni sohbet icin pencere (debounce) ve kullanici basina dakikalik ust sinir.
 * Uygulama ici kayit bundan etkilenmez, yalniz push atlanir. Redis erisilemezse acik (push gider).
 * Sohbet mesajlarinin kendi (daha yuksek) dakikalik siniri vardir ve diger turlerin sayacini tuketmez; mesaj penceresi
 * varsayilan olarak kapalidir (0): her mesaj kendi push'unu alir, Android `tag` / iOS `apns-collapse-id` ayni sohbetin
 * bildirimini cihazda tek satira indirir.
 */
@Component
public class PushGate {

    private static final Logger log = LoggerFactory.getLogger(PushGate.class);

    /** Sayac/kilit deposu (Redis ya da testte bellek). */
    public interface Store {
        /** Anahtar yoksa yazar ve true doner. */
        boolean setIfAbsent(String key, Duration ttl);

        /** Artirir; ilk artista TTL verilir. */
        long incr(String key, Duration ttl);
    }

    /** Hicbir sinir uygulamaz (birim testler). */
    public static final PushGate OPEN = new PushGate((Store) null, 0, 0, 0);

    private final Store store;
    private final Duration window;
    private final int maxPerMinute;
    /** Mesaj push'u icin ayri dakikalik sinir; 0 ise mesajlar genel sayaci paylasir (eski davranis). */
    private final int maxMessagesPerMinute;

    @Autowired
    public PushGate(ObjectProvider<StringRedisTemplate> redis,
                    @Value("${app.push.message-window-seconds:0}") int windowSeconds,
                    @Value("${app.push.max-per-minute:10}") int maxPerMinute,
                    @Value("${app.push.max-messages-per-minute:60}") int maxMessagesPerMinute) {
        this(redis.getIfAvailable() == null ? null : new RedisStore(redis.getIfAvailable()), windowSeconds, maxPerMinute,
                maxMessagesPerMinute);
    }

    public PushGate(Store store, int windowSeconds, int maxPerMinute) {
        this(store, windowSeconds, maxPerMinute, 0);
    }

    public PushGate(Store store, int windowSeconds, int maxPerMinute, int maxMessagesPerMinute) {
        this.store = store;
        this.window = Duration.ofSeconds(Math.max(0, windowSeconds));
        this.maxPerMinute = maxPerMinute;
        this.maxMessagesPerMinute = Math.max(0, maxMessagesPerMinute);
    }

    /**
     * Sohbet mesaji push'u: pencere icinde ayni sohbet icin ikinci push yok; kullanici basina dakikada ust sinir.
     * @return true: push gonderilebilir
     */
    public boolean allowMessagePush(Long userId, String conversationKey) {
        if (store == null) {
            return true;
        }
        try {
            if (!window.isZero() && !store.setIfAbsent("pushwin:" + userId + ":" + conversationKey, window)) {
                return false;
            }
            if (maxMessagesPerMinute > 0) {
                return store.incr("pushmsgcap:" + userId, Duration.ofMinutes(1)) <= maxMessagesPerMinute;
            }
            return underCap(userId);
        } catch (RuntimeException e) {
            log.debug("PushGate atlandi: {}", e.toString());
            return true;
        }
    }

    /** Mesaj disi turler icin yalnizca kullanici basina dakikalik sinir. */
    public boolean allowGeneralPush(Long userId) {
        if (store == null) {
            return true;
        }
        try {
            return underCap(userId);
        } catch (RuntimeException e) {
            return true;
        }
    }

    private boolean underCap(Long userId) {
        return maxPerMinute <= 0 || store.incr("pushcap:" + userId, Duration.ofMinutes(1)) <= maxPerMinute;
    }

    private record RedisStore(StringRedisTemplate redis) implements Store {
        @Override
        public boolean setIfAbsent(String key, Duration ttl) {
            return Boolean.TRUE.equals(redis.opsForValue().setIfAbsent(key, "1", ttl));
        }

        @Override
        public long incr(String key, Duration ttl) {
            Long n = redis.opsForValue().increment(key);
            if (n != null && n == 1L) {
                redis.expire(key, ttl);
            }
            return n == null ? 0 : n;
        }
    }
}
