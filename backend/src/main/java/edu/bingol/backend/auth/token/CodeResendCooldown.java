package edu.bingol.backend.auth.token;

import edu.bingol.backend.common.Hashing;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/**
 * Dogrulama kodu "yeniden iste" bekleme suresinin TEK kaynagi (varsayilan 180 sn, `app.auth.code-resend-cooldown-seconds`).
 * Kayit/e-posta dogrulama, sifre sifirlama, iki faktorlu giris/etkinlestirme ve herkese acik destek kodu ayni degeri
 * kullanir. Kod GECERLILIGI (10 dk) buradan bagimsizdir.
 *
 * <p>Redis `vcool:&lt;akis&gt;:&lt;ozet&gt;` (SET NX PX); ozet = SHA-256(normalize e-posta ya da konu), ham deger yazilmaz.
 * Anahtar hesabin var olup olmadigina BAKMAZ: cagiran hesap aramasindan ONCE rezerve eder, boylece var olmayan adres
 * de ayni 429'u alir (enumerasyon yok). Redis hatasi yukari atilir (fail-closed, mevcut davranis).
 */
@Component
public class CodeResendCooldown {

    public static final String VERIFY = "verify";
    public static final String RESET = "reset";
    public static final String TWO_FACTOR = "tf";
    public static final String SUPPORT = "support";

    public static final long DEFAULT_SECONDS = 180;

    private final StringRedisTemplate redis;

    @Value("${app.auth.code-resend-cooldown-seconds:" + DEFAULT_SECONDS + "}")
    private long seconds = DEFAULT_SECONDS;

    public CodeResendCooldown(StringRedisTemplate redis) {
        this.redis = redis;
    }

    /** Test/duman ortamlari icin sure ayari. */
    public void setSeconds(long seconds) {
        this.seconds = seconds;
    }

    /** Gecerli bekleme suresi (saniye, en az 1). */
    public long seconds() {
        return Math.max(1, seconds);
    }

    /**
     * Beklemeyi baslatir. Zaten sureliyse 429 RESEND_COOLDOWN (Retry-After = kalan saniye, en cok {@link #seconds()}).
     */
    public void acquire(String flow, String subject) {
        String key = key(flow, subject);
        Boolean first = redis.opsForValue().setIfAbsent(key, "1", Duration.ofSeconds(seconds()));
        if (!Boolean.TRUE.equals(first)) {
            throw new ResendCooldownException(remaining(key));
        }
    }

    /** Beklemeyi kaldirir (kod gonderilemediyse ya da akis tamamlandiysa). */
    public void release(String flow, String subject) {
        redis.delete(key(flow, subject));
    }

    private long remaining(String key) {
        Long ttl = redis.getExpire(key);
        long max = seconds();
        if (ttl == null || ttl < 0) {
            return max;
        }
        return Math.max(1, Math.min(ttl, max));
    }

    static String key(String flow, String subject) {
        return "vcool:" + flow + ":" + Hashing.sha256(subject).substring(0, 32);
    }
}
