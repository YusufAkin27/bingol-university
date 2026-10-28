package edu.bingol.backend.auth;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimitedException;
import java.time.Duration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Giris kaba kuvvet korumasi: YALNIZ BASARISIZ denemeler sayilir ve sayac (e-posta, istemci ag adresi) cifti
 * basinadir. Boylece baska bir ag adresinden hedef e-postaya yanlis parola gonderen biri gercek kullanicinin girisini
 * kilitleyemez (hedefli hesap kilitleme DoS'u); kampus NAT'inda tek ogrencinin hatasi digerlerini etkilemez.
 * Dagitik kaba kuvvete karsi e-posta basina (istemciden bagimsiz) daha yuksek bir ust sinir vardir.
 * Basarili giris cift sayacini sifirlar. Anahtarlar e-postanin ozetidir (ham deger/uzun girdi Redis'i sisirmez).
 */
@Component
public class LoginThrottle {

    static final int PAIR_MAX = 10;
    static final int EMAIL_MAX = 60;
    static final Duration WINDOW = Duration.ofMinutes(15);

    private final StringRedisTemplate redis;

    public LoginThrottle(StringRedisTemplate redis) {
        this.redis = redis;
    }

    /** Bu (e-posta, istemci) ya da e-posta genelinde limit doluysa 429 (parola kontrolunden ONCE, bcrypt maliyeti yok). */
    public void check(String email, String clientKey) {
        requireBelow(pairKey(email, clientKey), PAIR_MAX);
        requireBelow(emailKey(email), EMAIL_MAX);
    }

    public void recordFailure(String email, String clientKey) {
        bump(pairKey(email, clientKey));
        bump(emailKey(email));
    }

    public void recordSuccess(String email, String clientKey) {
        redis.delete(pairKey(email, clientKey));
    }

    private void requireBelow(String key, int max) {
        String v = redis.opsForValue().get(key);
        long n;
        try {
            n = v == null ? 0 : Long.parseLong(v);
        } catch (NumberFormatException e) {
            n = 0;
        }
        if (n >= max) {
            Long ttl = redis.getExpire(key);
            throw new RateLimitedException(ttl == null || ttl < 0 ? WINDOW.toSeconds() : ttl);
        }
    }

    private void bump(String key) {
        Long n = redis.opsForValue().increment(key);
        if (n == null) {
            return;
        }
        Long ttl = n == 1 ? null : redis.getExpire(key);
        if (n == 1 || ttl == null || ttl < 0) {
            redis.expire(key, WINDOW);
        }
    }

    static String digest(String email) {
        return Hashing.sha256(LoginIdentifier.aliasKey(email)).substring(0, 32);
    }

    private static String pairKey(String email, String clientKey) {
        return "lgf:p:" + digest(email) + ":" + clientKey;
    }

    private static String emailKey(String email) {
        return "lgf:e:" + digest(email);
    }
}
