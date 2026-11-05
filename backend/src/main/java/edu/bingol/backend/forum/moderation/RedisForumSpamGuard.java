package edu.bingol.backend.forum.moderation;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.forum.moderation.spi.ForumSpamGuard;
import edu.bingol.backend.forum.moderation.spi.ForumTextSanitizer;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Tekrarli icerik korumasi: Redis {@code SET NX PX} ({@code fspam:<kullanici>:<ozet>}); Redis yoksa/hata verirse
 * (yerel gelistirme, test) surec ici bellek tablosuna duser. Hata durumunda kullaniciyi engellemez (fail-open): bu
 * koruma kotu niyete karsi bir yavaslaticidir, yetki karari degildir; asil sinir {@code RateLimiter}'dadir.
 */
@Component
public class RedisForumSpamGuard implements ForumSpamGuard {

    private static final Logger log = LoggerFactory.getLogger(RedisForumSpamGuard.class);

    /** Bu uzunlugun altindaki (normalize) metinlerde anahtar baglami (konu) da icerir. */
    static final int SHORT_LIMIT = 20;
    private static final int MEMORY_PRUNE_AT = 5000;

    private final StringRedisTemplate redis;
    private final Duration window;
    private final Map<String, Long> memory = new ConcurrentHashMap<>();

    public RedisForumSpamGuard(StringRedisTemplate redis,
                               @Value("${app.forum.spam-window-seconds:600}") long windowSeconds) {
        this.redis = redis;
        this.window = Duration.ofSeconds(Math.max(1, windowSeconds));
    }

    @Override
    public void assertNotDuplicate(Long userId, String scope, Long contextId, String body) {
        String key = key(userId, scope, contextId, body);
        if (key == null) {
            return; // bos metin: bos icerik zaten dogrulamada reddedilir
        }
        if (!claim(key)) {
            throw new RateLimitedException("FORUM_DUPLICATE_CONTENT",
                    "Aynı içeriği kısa süre içinde tekrar gönderemezsiniz.", window.toSeconds());
        }
    }

    @Override
    public void forget(Long userId, String scope, Long contextId, String body) {
        String key = key(userId, scope, contextId, body);
        if (key == null) {
            return;
        }
        memory.remove(key);
        try {
            redis.delete(key);
        } catch (RuntimeException e) {
            log.debug("Forum spam isareti silinemedi: {}", e.toString());
        }
    }

    /** true = ilk kez (isaretlendi); false = pencere icinde zaten var. */
    private boolean claim(String key) {
        try {
            Boolean ok = redis.opsForValue().setIfAbsent(key, "1", window);
            if (ok != null) {
                return ok;
            }
        } catch (RuntimeException e) {
            log.debug("Forum spam korumasi Redis'siz calisiyor: {}", e.toString());
        }
        return claimInMemory(key);
    }

    private boolean claimInMemory(String key) {
        long now = System.currentTimeMillis();
        if (memory.size() > MEMORY_PRUNE_AT) {
            memory.values().removeIf(exp -> exp <= now);
        }
        boolean[] fresh = {false};
        memory.compute(key, (k, exp) -> {
            if (exp == null || exp <= now) {
                fresh[0] = true;
                return now + window.toMillis();
            }
            return exp;
        });
        return fresh[0];
    }

    /** Anahtar: kullanici + etiket + (kisa metinde baglam) + temizlenmis metnin ozeti; bos metin icin null. */
    static String key(Long userId, String scope, Long contextId, String body) {
        String norm = ForumTextSanitizer.compareKey(body);
        if (norm.isEmpty() || userId == null) {
            return null;
        }
        String ctx = norm.length() < SHORT_LIMIT && contextId != null ? ":" + contextId : "";
        return "fspam:" + userId + ":" + scope + ctx + ":" + Hashing.sha256(norm).substring(0, 32);
    }
}
