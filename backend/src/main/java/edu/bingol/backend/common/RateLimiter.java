package edu.bingol.backend.common;

import java.time.Duration;
import java.time.Instant;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Redis tabanli sabit pencere (fixed window) rate limit. Birden fazla sunucuda da ortak calisir.
 *
 * <p>Redis anahtar guvenligi (Redis 200 MB, kimliksiz yuzeyler ham girdiden anahtar kurar):
 * <ul>
 *   <li>Uzun anahtar ({@value #MAX_RAW_KEY} karakter ustu) SHA-256 ozetiyle kisaltilir: boylece bellek basina anahtar
 *       boyutu sabittir ve ham girdi (e-posta, baslik) anahtarda saklanmaz.</li>
 *   <li>Her anahtarin TTL'i vardir (ilk INCR'de; eksik TTL sonraki cagrida onarilir).</li>
 *   <li>Saatlik YENI anahtar butcesi ({@code app.ratelimit.max-new-keys-per-hour}): asildiginda yeni anahtar yaratilmaz,
 *       istek, o oneke ait ORTAK taşma kovasina (limit x {@code app.ratelimit.overflow-multiplier}) sayilir. Boylece
 *       rastgele e-posta/IP uretiminin Redis'i doldurmasi sinirlanir; mesru kullanicilar yalnizca saldiri sirasinda daha
 *       gevsek ortak limite duser (hizmet dusmez).</li>
 * </ul>
 */
@Component
public class RateLimiter {

    /** Bu uzunlugu asan anahtarlar ozetlenir. */
    static final int MAX_RAW_KEY = 80;

    private final StringRedisTemplate redis;

    @Value("${app.ratelimit.max-new-keys-per-hour:200000}")
    private long newKeyBudget = 200_000;
    @Value("${app.ratelimit.overflow-multiplier:50}")
    private int overflowMultiplier = 50;

    public RateLimiter(StringRedisTemplate redis) {
        this.redis = redis;
    }

    /** `key` icin pencere icinde `max` istegi asarsa 429 firlatir. */
    public void check(String key, int max, Duration window) {
        String k = "rl:" + safeKey(key);
        Long n = redis.opsForValue().increment(k);
        if (n == null) {
            return;
        }
        if (n == 1) {
            redis.expire(k, window);
            if (overBudget()) {
                // Yeni anahtar butcesi doldu: bu anahtari bellekten at, ortak tasma kovasina say
                redis.delete(k);
                k = "rl:ovf:" + prefixOf(key);
                n = redis.opsForValue().increment(k);
                if (n == null) {
                    return;
                }
                if (n == 1) {
                    redis.expire(k, window);
                }
                max = (int) Math.min(Integer.MAX_VALUE, (long) max * Math.max(1, overflowMultiplier));
            }
        } else if (redis.getExpire(k) < 0) {
            redis.expire(k, window); // TTL'siz kalan anahtar (nadir) onarilir
        }
        if (n > max) {
            Long ttl = redis.getExpire(k);
            throw new RateLimitedException(ttl == null || ttl < 0 ? window.toSeconds() : ttl);
        }
    }

    /** Uzun anahtari sabit boyuta indirir (onek + ozet); kisa anahtar aynen kalir. */
    static String safeKey(String key) {
        if (key == null) {
            return "null";
        }
        if (key.length() <= MAX_RAW_KEY) {
            return key;
        }
        return key.substring(0, 32) + "#" + Hashing.sha256(key).substring(0, 32);
    }

    /** Anahtarin ilk bolumu (login, forgot, ...): tasma kovasinin adi. */
    static String prefixOf(String key) {
        if (key == null) {
            return "null";
        }
        int i = key.indexOf(':');
        String p = i > 0 ? key.substring(0, i) : key;
        return p.length() > 24 ? p.substring(0, 24) : p;
    }

    /** Bu saatte olusturulan yeni anahtar sayisini artirir; butce asildiysa true. */
    private boolean overBudget() {
        if (newKeyBudget <= 0) {
            return false;
        }
        String bk = "rlnew:" + (Instant.now().getEpochSecond() / 3600);
        Long c = redis.opsForValue().increment(bk);
        if (c == null) {
            return false;
        }
        if (c == 1) {
            redis.expire(bk, Duration.ofHours(2));
        }
        return c > newKeyBudget;
    }
}
