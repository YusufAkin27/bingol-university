package edu.bingol.backend.auth;

import edu.bingol.backend.common.RateLimitedException;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Hesap basina gecici kilit (6 haneli PIN icin ZORUNLU kaba kuvvet korumasi: 6 hane = 1.000.000 olasilik).
 * {@value #MAX_FAILURES} ardisik yanlis sifreden sonra hesap {@code LOCK} (15 dk) kilitlenir: 429 ACCOUNT_TEMP_LOCKED
 * + Retry-After; kilitliyken DOGRU sifre de reddedilir (parola kontrolune hic ulasmaz). Basarili giriste sayac
 * silinir. Sayac Redis'te {@code lf:<e-posta ozeti>} (TTL 15 dk); anahtar e-postanin ozetidir (+etiket ayni sayaci
 * paylasir) ve hesap olsun olmasin AYNI sayilir: var olmayan adres icin de ayni cevap (kullanici sizmaz).
 * Not: bu kilit, LoginThrottle'daki "tanidik cihaz" muafiyetini tanimaz; kasitli taviz (sahibin hesabi 15 dk
 * kilitlenebilir, "Sifremi unuttum" akisi kilitten bagimsiz calisir).
 */
@Component
public class AccountLock {

    static final int MAX_FAILURES = 5;
    static final Duration LOCK = Duration.ofMinutes(15);

    private final StringRedisTemplate redis;

    @Autowired
    public AccountLock(StringRedisTemplate redis) {
        this.redis = redis;
    }

    /** Hesap kilitliyse 429 ACCOUNT_TEMP_LOCKED (parola kontrolunden ONCE cagrilir). */
    public void requireUnlocked(String email) {
        String key = key(email);
        String v = redis.opsForValue().get(key);
        long n;
        try {
            n = v == null ? 0 : Long.parseLong(v);
        } catch (NumberFormatException e) {
            n = 0;
        }
        if (n >= MAX_FAILURES) {
            Long ttl = redis.getExpire(key);
            throw new AccountLockedException(ttl == null || ttl < 0 ? LOCK.toSeconds() : ttl);
        }
    }

    /** Yanlis sifre: sayaci artirir; MAX_FAILURES'e ulasinca kilit suresi bu andan itibaren 15 dk baslar. */
    public void recordFailure(String email) {
        String key = key(email);
        Long n = redis.opsForValue().increment(key);
        if (n == null) {
            return;
        }
        // 1. denemede pencere acilir; kilit aninda sure yenilenir (kilit 5. hatadan itibaren tam 15 dk)
        if (n == 1 || n == MAX_FAILURES) {
            redis.expire(key, LOCK);
            return;
        }
        Long ttl = redis.getExpire(key);
        if (ttl == null || ttl < 0) {
            redis.expire(key, LOCK); // TTL'siz kalan sayac hesabi sonsuza dek kilitlemesin
        }
    }

    /** Basarili giris: sayaci sifirlar. */
    public void recordSuccess(String email) {
        redis.delete(key(email));
    }

    static String key(String email) {
        return "lf:" + LoginThrottle.digest(email);
    }

    /** 429 ACCOUNT_TEMP_LOCKED. */
    public static class AccountLockedException extends RateLimitedException {
        AccountLockedException(long retryAfterSeconds) {
            super("ACCOUNT_TEMP_LOCKED", "Çok fazla hatalı şifre denemesi. Hesap geçici olarak kilitlendi.",
                    retryAfterSeconds);
        }
    }
}
