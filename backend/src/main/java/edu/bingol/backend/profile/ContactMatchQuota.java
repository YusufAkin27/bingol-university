package edu.bingol.backend.profile;

import edu.bingol.backend.common.RateLimitedException;
import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneId;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Rehber eslestirme gunluk aday tavani (T-061): hesap basina gunde en cok {@code app.contacts.daily-candidate-cap}
 * (2000) benzersiz aday ozeti. Saatlik istek limiti tek basina yetmez (6 x 500 = 3000/saat); ogrenci dizinini
 * tarayan hesap gunluk tavana takilir. Sayac Redis'te (gun anahtari, Europe/Istanbul), tavani asan istek SAYILMAZ
 * (kullanici daha kucuk bir listeyle yine deneyebilir).
 */
@Component
public class ContactMatchQuota {

    static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");

    private final StringRedisTemplate redis;
    private final int cap;

    public ContactMatchQuota(StringRedisTemplate redis,
                             @Value("${app.contacts.daily-candidate-cap:2000}") int cap) {
        this.redis = redis;
        this.cap = Math.max(1, cap);
    }

    /** n adayi bugunun sayacina ekler; tavan asilirsa geri alir ve 429 firlatir. */
    public void consume(Long userId, int n) {
        if (n <= 0) {
            return;
        }
        String key = "cm:day:" + userId + ":" + LocalDate.now(ZONE);
        Long total = redis.opsForValue().increment(key, n);
        if (total == null) {
            return;
        }
        if (total == n) {
            redis.expire(key, Duration.ofHours(30));
        }
        if (total > cap) {
            redis.opsForValue().decrement(key, n);
            Long ttl = redis.getExpire(key);
            if (ttl == null || ttl < 0) {
                redis.expire(key, Duration.ofHours(30));
                ttl = Duration.ofHours(24).toSeconds();
            }
            throw new RateLimitedException(ttl);
        }
    }

    int cap() {
        return cap;
    }
}
