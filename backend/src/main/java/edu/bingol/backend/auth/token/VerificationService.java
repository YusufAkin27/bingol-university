package edu.bingol.backend.auth.token;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.List;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * 6 haneli e-posta kodu: Redis'te hash'li, 10 dk omurlu, en fazla 5 yanlis deneme.
 * Limit asilirsa kod silinmez, adres gecici kilitlenir (baskasi yanlis denemelerle gercek kullanicinin kodunu
 * yakamasin); yeni kod istegi kilidi ve sayaci sifirlar. Dogru kod tek kullanimliktir.
 * Iki amac ayri anahtar alaninda tutulur: "vc" e-posta dogrulama, "pr" sifre sifirlama.
 */
@Service
public class VerificationService {

    static final Duration CODE_TTL = Duration.ofMinutes(10);
    static final Duration LOCK_TTL = Duration.ofMinutes(10);
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);
    static final int MAX_ATTEMPTS = 5;

    private static final String VERIFY = "vc";
    private static final String RESET = "pr";

    private final StringRedisTemplate redis;
    private final MailService mail;
    private final SecureRandom random = new SecureRandom();

    public VerificationService(StringRedisTemplate redis, MailService mail) {
        this.redis = redis;
        this.mail = mail;
    }

    /** Yeni kayit dogrulama kodu uretip gonderir. Ayni adrese 60 sn icinde tekrar gonderimi reddeder. */
    public void issue(String email, Lang lang) {
        issue(VERIFY, email, lang);
    }

    /** Sifre sifirlama kodu uretip gonderir (ayri anahtar alani, ayni kurallar). */
    public void issueReset(String email, Lang lang) {
        issue(RESET, email, lang);
    }

    /** Kod dogruysa true (ve kod tuketilir); yanlis/suresi gecmisse false; kilitliyse veya limit asilirsa 429. */
    public boolean verify(String email, String code) {
        return verify(VERIFY, email, code);
    }

    public boolean verifyReset(String email, String code) {
        return verify(RESET, email, code);
    }

    /** Kod dogrulandiktan sonra 10 dk gecerli, tek kullanimlik sifirlama anahtari uretir (yalniz hash'i saklanir). */
    public String issueResetToken(String email) {
        byte[] raw = new byte[32];
        random.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        redis.opsForValue().set("prt:" + email, Hashing.sha256(token), CODE_TTL);
        return token;
    }

    /** Anahtar eslesirse tuketir ve true doner; getAndDelete ile es zamanli iki istekten yalniz biri gecer. */
    public boolean consumeResetToken(String email, String token) {
        String stored = redis.opsForValue().getAndDelete("prt:" + email);
        return stored != null && MessageDigest.isEqual(stored.getBytes(StandardCharsets.UTF_8),
                Hashing.sha256(token).getBytes(StandardCharsets.UTF_8));
    }

    private void issue(String ns, String email, Lang lang) {
        Boolean first = redis.opsForValue().setIfAbsent(ns + ":cd:" + email, "1", RESEND_COOLDOWN);
        if (!Boolean.TRUE.equals(first)) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RESEND_COOLDOWN",
                    "Yeni kod için lütfen 1 dakika bekleyin.");
        }
        String code = String.format("%06d", random.nextInt(1_000_000));
        redis.opsForValue().set(ns + ":" + email, hash(email, code), CODE_TTL);
        redis.delete(List.of(ns + ":att:" + email, ns + ":lock:" + email));
        try {
            if (RESET.equals(ns)) {
                mail.sendPasswordResetCode(email, code, (int) CODE_TTL.toMinutes(), lang);
            } else {
                mail.sendVerificationCode(email, code, (int) CODE_TTL.toMinutes(), lang);
            }
        } catch (RuntimeException e) {
            // Gonderilemediyse bekleme suresi kullaniciyi cezalandirmasin.
            redis.delete(ns + ":cd:" + email);
            redis.delete(ns + ":" + email);
            throw e;
        }
    }

    private boolean verify(String ns, String email, String code) {
        if (Boolean.TRUE.equals(redis.hasKey(ns + ":lock:" + email))) {
            throw tooManyAttempts();
        }
        String stored = redis.opsForValue().get(ns + ":" + email);
        if (stored == null) {
            return false;
        }
        Long attempts = redis.opsForValue().increment(ns + ":att:" + email);
        if (attempts != null && attempts == 1) {
            redis.expire(ns + ":att:" + email, CODE_TTL);
        }
        if (attempts != null && attempts > MAX_ATTEMPTS) {
            redis.opsForValue().set(ns + ":lock:" + email, "1", LOCK_TTL);
            throw tooManyAttempts();
        }
        boolean match = MessageDigest.isEqual(stored.getBytes(StandardCharsets.UTF_8),
                hash(email, code).getBytes(StandardCharsets.UTF_8));
        if (!match) {
            return false;
        }
        // delete() yalnizca ilk cagirana true doner: es zamanli iki istekten biri kodu kullanir.
        boolean consumed = Boolean.TRUE.equals(redis.delete(ns + ":" + email));
        redis.delete(ns + ":att:" + email);
        return consumed;
    }

    private static ApiException tooManyAttempts() {
        return new ApiException(HttpStatus.TOO_MANY_REQUESTS, "TOO_MANY_ATTEMPTS",
                "Çok fazla hatalı deneme. Yeni kod isteyin.");
    }

    private static String hash(String email, String code) {
        return Hashing.sha256(email + ":" + code);
    }
}
