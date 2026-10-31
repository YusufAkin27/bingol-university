package edu.bingol.backend.auth;

import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.config.RateLimitProperties;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Giris kaba kuvvet korumasi: YALNIZ BASARISIZ denemeler sayilir (15 dk pencere). Katmanlar:
 * <ul>
 *   <li>(e-posta, cihaz) cifti - cihaz kimligi (X-Device-Id ozeti) varsa; yoksa (e-posta, IP) cifti: hesap korumasi
 *       ({@code loginPairFailMax}, varsayilan 10). Ayni kampus NAT'indaki baska bir ogrencinin yanlis denemeleri
 *       digerinin girisini kilitlemez (cihaz farkli).</li>
 *   <li>(e-posta, IP) cifti ({@code loginEmailIpFailMax}): cihaz kimligini degistirerek tek IP'den hesap denemeyi keser.</li>
 *   <li>E-posta basina istemciden bagimsiz tavan ({@code loginEmailFailMax}, 60): dagitik kaba kuvvetin kesin siniri;
 *       hesap basina toplam deneme siniri cihaz/IP degisiminden etkilenmez.</li>
 *   <li>Cihaz basina ({@code loginDeviceFailMax}): farkli hesaplari tarayan cihaz.</li>
 *   <li>IP basina ({@code loginIpFailMax}, yuksek): NAT'i sagir etmeyecek kadar genis credential stuffing tavani.</li>
 * </ul>
 * <p>HEDEFLI KILITLEME (DoS) KORUMASI (T-006): e-posta basina tavan YALNIZ "bilinmeyen" istemciler icindir. Hesapla
 * daha once basarili giris yapmis cihaz (cihaz kimligi yoksa IP) {@code lgf:ok:*} isaretiyle {@link #TRUST_TTL} boyunca
 * "tanidik" sayilir: tavan onlara uygulanmaz ve onlarin hatalari tavani doldurmaz; saldirgan sahte cihaz kimlikleriyle
 * hesabin gercek sahibini kilitleyemez. Tanidik istemcinin KENDI cift sayaci (10) yine uygulanir.
 * Basarili giris cift sayaclarini sifirlar. Anahtarlar e-postanin ozetidir (ham deger/uzun girdi Redis'i sisirmez).
 */
@Component
public class LoginThrottle {

    static final int PAIR_MAX = 10;
    static final int EMAIL_MAX = 60;
    static final Duration WINDOW = Duration.ofMinutes(15);
    /** Basarili girisle "tanidik" sayilan istemci isareti omru. */
    static final Duration TRUST_TTL = Duration.ofDays(30);

    private final StringRedisTemplate redis;
    private final RateLimitProperties limits;

    @Autowired
    public LoginThrottle(StringRedisTemplate redis, RateLimitProperties limits) {
        this.redis = redis;
        this.limits = limits;
    }

    public LoginThrottle(StringRedisTemplate redis) {
        this(redis, RateLimitProperties.defaults());
    }

    /** Bu (e-posta, istemci) ya da e-posta genelinde limit doluysa 429 (parola kontrolunden ONCE, bcrypt maliyeti yok). */
    public void check(String email, String clientKey) {
        check(email, clientKey, null);
    }

    /** `deviceHash` yoksa null. */
    public void check(String email, String clientKey, String deviceHash) {
        requireBelow(ipFailKey(clientKey), limits.loginIpFailMax());
        if (deviceHash != null) {
            requireBelow(deviceFailKey(deviceHash), limits.loginDeviceFailMax());
            requireBelow(devicePairKey(email, deviceHash), limits.loginPairFailMax());
            requireBelow(pairKey(email, clientKey), limits.loginEmailIpFailMax());
        } else {
            requireBelow(pairKey(email, clientKey), limits.loginPairFailMax());
        }
        if (!trusted(email, clientKey, deviceHash)) {
            requireBelow(emailKey(email), limits.loginEmailFailMax());
        }
    }

    public void recordFailure(String email, String clientKey) {
        recordFailure(email, clientKey, null);
    }

    public void recordFailure(String email, String clientKey, String deviceHash) {
        bump(pairKey(email, clientKey));
        if (!trusted(email, clientKey, deviceHash)) {
            bump(emailKey(email)); // tanidik istemcinin hatalari hesap geneli tavani doldurmaz
        }
        bump(ipFailKey(clientKey));
        if (deviceHash != null) {
            bump(devicePairKey(email, deviceHash));
            bump(deviceFailKey(deviceHash));
        }
    }

    public void recordSuccess(String email, String clientKey) {
        recordSuccess(email, clientKey, null);
    }

    public void recordSuccess(String email, String clientKey, String deviceHash) {
        try {
            redis.opsForValue().set(trustKey(email, clientKey, deviceHash), "1", TRUST_TTL);
        } catch (RuntimeException e) {
            // isaret en-iyi-caba; giris akisini bozmaz
        }
        redis.delete(pairKey(email, clientKey));
        if (deviceHash != null) {
            redis.delete(devicePairKey(email, deviceHash));
        }
    }

    /** Bu hesapla daha once basarili giris yapmis istemci mi (bkz. sinif aciklamasi)? */
    private boolean trusted(String email, String clientKey, String deviceHash) {
        return Boolean.TRUE.equals(redis.hasKey(trustKey(email, clientKey, deviceHash)));
    }

    private static String trustKey(String email, String clientKey, String deviceHash) {
        return "lgf:ok:" + digest(email) + ":" + (deviceHash != null ? "d:" + deviceHash : "i:" + clientKey);
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

    private static String devicePairKey(String email, String deviceHash) {
        return "lgf:pd:" + digest(email) + ":" + deviceHash;
    }

    private static String deviceFailKey(String deviceHash) {
        return "lgf:d:" + deviceHash;
    }

    private static String ipFailKey(String clientKey) {
        return "lgf:i:" + clientKey;
    }

    private static String emailKey(String email) {
        return "lgf:e:" + digest(email);
    }
}
