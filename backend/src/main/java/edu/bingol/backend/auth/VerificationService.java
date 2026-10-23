package edu.bingol.backend.auth;

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
    public void issue(String email) {
        Boolean first = redis.opsForValue().setIfAbsent("vc:cd:" + email, "1", RESEND_COOLDOWN);
        if (!Boolean.TRUE.equals(first)) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RESEND_COOLDOWN",
                    "Yeni kod için lütfen 1 dakika bekleyin.");
        }
        String code = String.format("%06d", random.nextInt(1_000_000));
        redis.opsForValue().set("vc:" + email, hash(email, code), CODE_TTL);
        redis.delete("vc:att:" + email);
        try {
            mail.sendVerificationCode(email, code, (int) CODE_TTL.toMinutes());
        } catch (RuntimeException e) {
            // Gonderilemediyse bekleme suresi kullaniciyi cezalandirmasin.
            redis.delete("vc:cd:" + email);
            redis.delete("vc:" + email);
            throw e;
        }
    }

    /** Kod dogruysa true; yanlis/suresi gecmisse false; deneme limiti asilirsa 429. */
    public boolean verify(String email, String code) {
        String stored = redis.opsForValue().get("vc:" + email);
        if (stored == null) {
            return false;
        }
        Long attempts = redis.opsForValue().increment("vc:att:" + email);
        if (attempts != null && attempts == 1) {
            redis.expire("vc:att:" + email, CODE_TTL);
        }
        if (attempts != null && attempts > MAX_ATTEMPTS) {
            redis.delete("vc:" + email);
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "TOO_MANY_ATTEMPTS",
                    "Çok fazla hatalı deneme. Yeni kod isteyin.");
        }
        boolean ok = MessageDigest.isEqual(stored.getBytes(StandardCharsets.UTF_8),
                hash(email, code).getBytes(StandardCharsets.UTF_8));
        if (ok) {
            redis.delete(java.util.List.of("vc:" + email, "vc:att:" + email));
        }
        return ok;
    }

    private static String hash(String email, String code) {
        return Hashing.sha256(email + ":" + code);
    }
}
