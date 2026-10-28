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
 *
 * Hedefli kilitleme (DoS) ve kod yenilemeyle sayac sifirlama:
 * - `scope` (istemci anahtari, IPv6 /64'e indirgenmis IP) verilirse yanlis deneme sayaci (e-posta, istemci) cifti
 *   basinadir: baska bir ag adresindeki saldirgan gercek kullanicinin sayacini/kilidini tuketemez.
 * - Kod basina KUME siniri (`GLOBAL_ATTEMPTS`) istemciden bagimsizdir; yeni kod bunu sifirlar.
 * - Yeni kod, saatlik toplam yanlis deneme sayacini (`tot`) SIFIRLAMAZ: dakikada bir yenilenen kodlarla 5'er
 *   tahmin yapmak engellenir; toplam `MAX_HOURLY_WRONG` asilirsa adres kilitli kalir (yeni kod kilidi acmaz).
 */
@Service
public class VerificationService {

    static final Duration CODE_TTL = Duration.ofMinutes(10);
    static final Duration LOCK_TTL = Duration.ofMinutes(10);
    private static final Duration RESEND_COOLDOWN = Duration.ofSeconds(60);
    static final int MAX_ATTEMPTS = 5;
    /** Bir kod icin tum istemcilerden toplam deneme siniri (istemci basina sinirin ustunde, DoS'a kapali). */
    static final int GLOBAL_ATTEMPTS = 20;
    /** Adres basina saatlik toplam yanlis deneme (kod yenilemeye ragmen); tahmin olasiligi saatte en fazla 60/1e6. */
    static final int MAX_HOURLY_WRONG = 60;
    private static final Duration TOTAL_TTL = Duration.ofHours(1);

    private static final String VERIFY = "vc";
    private static final String RESET = "pr";

    private final StringRedisTemplate redis;
    private final MailService mail;
    private final SecureRandom random = new SecureRandom();

    public VerificationService(StringRedisTemplate redis, MailService mail) {
        this.redis = redis;
        this.mail = mail;
    }

    /** Gunluk e-posta kotasi doluysa genel 503 MAIL_QUOTA_EXHAUSTED (e-postadan bagimsiz: enumerasyon yok). */
    public void requireMailQuota() {
        mail.requireCodeQuota();
    }

    /** Yeni kayit dogrulama kodu uretip gonderir. Ayni adrese 60 sn icinde tekrar gonderimi reddeder. */
    public void issue(String email, Lang lang) {
        issue(VERIFY, email, lang);
    }

    /** Sifre sifirlama kodu uretip gonderir (ayri anahtar alani, ayni kurallar). */
    public void issueReset(String email, Lang lang) {
        issue(RESET, email, lang);
    }

    /** Yonetici dogrulamasindan sonra e-posta dogrulama kodunu, sayaclarini, kilidini ve beklemeyi temizler. */
    public void clearVerify(String email) {
        redis.delete(List.of(VERIFY + ":" + email, VERIFY + ":att:" + email, VERIFY + ":lock:" + email,
                VERIFY + ":cd:" + email));
    }

    /** Kod dogruysa true (ve kod tuketilir); yanlis/suresi gecmisse false; kilitliyse veya limit asilirsa 429. */
    public boolean verify(String email, String code) {
        return verify(VERIFY, email, code, null);
    }

    /** `scope`: istemci anahtari (bkz. sinif aciklamasi); null = yalniz adres bazli (eski davranis). */
    public boolean verify(String email, String code, String scope) {
        return verify(VERIFY, email, code, scope);
    }

    /**
     * Kodu tuketmeden BIR yanlis deneme sayar (kayit dogrulamasinda parola kaniti basarisizsa): sayaclar/kilitler
     * gercek yanlis kodla ayni islenir; kilit asilirsa 429 firlatir. Dogru kod bu yolla asla tuketilmez.
     */
    public void recordWrongAttempt(String email, String scope) {
        // 6 hane olmayan deger hicbir kodla eslesmez: yalniz yanlis deneme sayilir
        verify(VERIFY, email, "x", scope);
    }

    public boolean verifyReset(String email, String code) {
        return verify(RESET, email, code, null);
    }

    public boolean verifyReset(String email, String code, String scope) {
        return verify(RESET, email, code, scope);
    }

    /** Kod dogrulandiktan sonra 10 dk gecerli, tek kullanimlik sifirlama anahtari uretir (yalniz hash'i saklanir). */
    public String issueResetToken(String email) {
        byte[] raw = new byte[32];
        random.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        redis.opsForValue().set("prt:" + email, Hashing.sha256(token), CODE_TTL);
        return token;
    }

    /**
     * Anahtar eslesirse tuketir ve true doner. Once karsilastirilir, yalniz eslesirse silinir: yanlis anahtarli
     * istek gercek kullanicinin gecerli anahtarini yakmaz. delete() ile es zamanli iki istekten yalniz biri gecer.
     */
    public boolean consumeResetToken(String email, String token) {
        String key = "prt:" + email;
        String stored = redis.opsForValue().get(key);
        if (stored == null || !MessageDigest.isEqual(stored.getBytes(StandardCharsets.UTF_8),
                Hashing.sha256(token).getBytes(StandardCharsets.UTF_8))) {
            return false;
        }
        return Boolean.TRUE.equals(redis.delete(key));
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
        redis.delete(ns + ":gatt:" + email);
        // Saatlik toplam yanlis deneme siniri asildiysa yeni kod kilidi ACMAZ (sayac sifirlama yolu kapali).
        if (totalWrong(ns, email) > MAX_HOURLY_WRONG) {
            redis.opsForValue().set(ns + ":lock:" + email, "1", LOCK_TTL);
        }
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

    private long totalWrong(String ns, String email) {
        String v = redis.opsForValue().get(ns + ":tot:" + email);
        try {
            return v == null ? 0 : Long.parseLong(v);
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    private boolean verify(String ns, String email, String code, String scope) {
        String scoped = scope == null || scope.isBlank() ? null : ns + ":sc:" + email + ":" + scope;
        if (Boolean.TRUE.equals(redis.hasKey(ns + ":lock:" + email))
                || (scoped != null && Boolean.TRUE.equals(redis.hasKey(scoped + ":lock")))) {
            throw tooManyAttempts();
        }
        String stored = redis.opsForValue().get(ns + ":" + email);
        if (stored == null) {
            return false;
        }
        // Istemci (e-posta, istemci) cifti basina sayac; scope yoksa adres basina (eski davranis).
        String attKey = scoped != null ? scoped + ":att" : ns + ":att:" + email;
        String lockKey = scoped != null ? scoped + ":lock" : ns + ":lock:" + email;
        Long attempts = redis.opsForValue().increment(attKey);
        if (attempts != null && attempts == 1) {
            redis.expire(attKey, CODE_TTL);
        }
        if (attempts != null && attempts > MAX_ATTEMPTS) {
            redis.opsForValue().set(lockKey, "1", LOCK_TTL);
            throw tooManyAttempts();
        }
        if (scoped != null) {
            // Kod basina tum istemcilerden toplam: dagitik deneme tek kodu sonsuz zorlayamaz (yeni kod sifirlar).
            String gKey = ns + ":gatt:" + email;
            Long total = redis.opsForValue().increment(gKey);
            if (total != null && total == 1) {
                redis.expire(gKey, CODE_TTL);
            }
            if (total != null && total > GLOBAL_ATTEMPTS) {
                redis.opsForValue().set(ns + ":lock:" + email, "1", LOCK_TTL);
                throw tooManyAttempts();
            }
        }
        boolean match = MessageDigest.isEqual(stored.getBytes(StandardCharsets.UTF_8),
                hash(email, code).getBytes(StandardCharsets.UTF_8));
        if (!match) {
            // Yeni kodla sifirlanmayan saatlik toplam sayac (kod yenileyerek tahmin sayisini artirma yolunu kapatir).
            String tKey = ns + ":tot:" + email;
            Long wrong = redis.opsForValue().increment(tKey);
            if (wrong != null && wrong == 1) {
                redis.expire(tKey, TOTAL_TTL);
            }
            if (wrong != null && wrong > MAX_HOURLY_WRONG) {
                redis.opsForValue().set(ns + ":lock:" + email, "1", LOCK_TTL);
                throw tooManyAttempts();
            }
            return false;
        }
        // delete() yalnizca ilk cagirana true doner: es zamanli iki istekten biri kodu kullanir.
        boolean consumed = Boolean.TRUE.equals(redis.delete(ns + ":" + email));
        redis.delete(List.of(ns + ":att:" + email, ns + ":tot:" + email));
        if (scoped != null) {
            redis.delete(List.of(scoped + ":att", ns + ":gatt:" + email));
        }
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
