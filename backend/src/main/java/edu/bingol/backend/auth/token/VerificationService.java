package edu.bingol.backend.auth.token;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.Hashing;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.mail.MailService;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** 6 haneli e-posta dogrulama kodu: Redis'te hash'li, 10 dk omurlu, en fazla 5 yanlis deneme. */
@Service
public class VerificationService {

    private static final Duration CODE_TTL = Duration.ofMinutes(10);
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);
    private static final int MAX_ATTEMPTS = 5;

    private final StringRedisTemplate redis;
    private final MailService mail;
    private final SecureRandom random = new SecureRandom();

    public VerificationService(StringRedisTemplate redis, MailService mail) {
        this.redis = redis;
        this.mail = mail;
    }

    /** Yeni kod uretip gonderir. Ayni adrese 60 sn icinde tekrar gonderimi reddeder. */
    public void issue(String email, Lang lang) {
        issue("vc", email, lang);
    }

    /** Sifre sifirlama kodu: ayni mekanizma, ayri Redis anahtar alani (pr:*). */
    public void issueReset(String email, Lang lang) {
        issue("pr", email, lang);
    }

    public boolean verifyReset(String email, String code) {
        return verify("pr", email, code);
    }

    private void issue(String ns, String email, Lang lang) {
        Boolean first = redis.opsForValue().setIfAbsent(ns + ":cd:" + email, "1", RESEND_COOLDOWN);
        if (!Boolean.TRUE.equals(first)) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RESEND_COOLDOWN",
                    "Yeni kod için lütfen 1 dakika bekleyin.");
        }
        String code = String.format("%06d", random.nextInt(1_000_000));
        redis.opsForValue().set(ns + ":" + email, hash(email, code), CODE_TTL);
        redis.delete(ns + ":att:" + email);
        try {
            if ("pr".equals(ns)) {
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

    /** Kod dogruysa true; yanlis/suresi gecmisse false; deneme limiti asilirsa 429. */
    public boolean verify(String email, String code) {
        return verify("vc", email, code);
    }

    private boolean verify(String ns, String email, String code) {
        String stored = redis.opsForValue().get(ns + ":" + email);
        if (stored == null) {
            return false;
        }
        Long attempts = redis.opsForValue().increment(ns + ":att:" + email);
        if (attempts != null && attempts == 1) {
            redis.expire(ns + ":att:" + email, CODE_TTL);
        }
        if (attempts != null && attempts > MAX_ATTEMPTS) {
            redis.delete(ns + ":" + email);
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "TOO_MANY_ATTEMPTS",
                    "Çok fazla hatalı deneme. Yeni kod isteyin.");
        }
        boolean ok = MessageDigest.isEqual(stored.getBytes(StandardCharsets.UTF_8),
                hash(email, code).getBytes(StandardCharsets.UTF_8));
        if (ok) {
            redis.delete(java.util.List.of(ns + ":" + email, ns + ":att:" + email));
        }
        return ok;
    }

    /** Kod dogrulandiktan sonra 10 dk gecerli, tek kullanimlik sifirlama anahtari uretir (yalniz hash'i saklanir). */
    public String issueResetToken(String email) {
        byte[] raw = new byte[32];
        random.nextBytes(raw);
        String token = java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        redis.opsForValue().set("prt:" + email, Hashing.sha256(token), CODE_TTL);
        return token;
    }

    /** Anahtar eslesirse tuketir (tek kullanim) ve true doner. */
    public boolean consumeResetToken(String email, String token) {
        String stored = redis.opsForValue().get("prt:" + email);
        if (stored == null) {
            return false;
        }
        boolean ok = MessageDigest.isEqual(stored.getBytes(StandardCharsets.UTF_8),
                Hashing.sha256(token).getBytes(StandardCharsets.UTF_8));
        if (ok) {
            redis.delete("prt:" + email);
        }
        return ok;
    }

    private static String hash(String email, String code) {
        return Hashing.sha256(email + ":" + code);
    }
}
