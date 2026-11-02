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
 * Yeniden kod isteme beklemesi (varsayilan 180 sn) {@link CodeResendCooldown}'dadir (Redis `vcool:*`); kod gecerliligi
 * (10 dk) ondan bagimsizdir.
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
    static final int MAX_ATTEMPTS = 5;
    /** Bir kod icin tum istemcilerden toplam deneme siniri (istemci basina sinirin ustunde, DoS'a kapali). */
    static final int GLOBAL_ATTEMPTS = 20;
    /** Adres basina saatlik toplam yanlis deneme (kod yenilemeye ragmen); tahmin olasiligi saatte en fazla 60/1e6. */
    static final int MAX_HOURLY_WRONG = 60;
    private static final Duration TOTAL_TTL = Duration.ofHours(1);

    private static final String VERIFY = "vc";
    private static final String RESET = "pr";
    /** Iki faktorlu giris/etkinlestirme kodu: anahtar `tf:<kullanici kimligi>` (bkz. issueTwoFactor). */
    private static final String TWO_FACTOR = "tf";

    private final StringRedisTemplate redis;
    private final MailService mail;
    private CodeResendCooldown cooldown;
    private final SecureRandom random = new SecureRandom();
    /**
     * Kod ozeti icin gizli tuz (T-009): 6 haneli kodun SHA-256'si tuzsuzken Redis sizintisinda 1e6 denemeyle kirilirdi.
     * HMAC-SHA256(pepper, e-posta:kod). Bos ise (birim testleri) duz SHA-256.
     */
    @org.springframework.beans.factory.annotation.Value("${app.auth.code-pepper:${jwt.secret:}}")
    private String pepper = "";

    public VerificationService(StringRedisTemplate redis, MailService mail) {
        this.redis = redis;
        this.mail = mail;
    }

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setCooldown(CodeResendCooldown cooldown) {
        this.cooldown = cooldown;
    }

    /** Birim testleri Spring disinda kurar: varsayilan sureyle yerel ornek. */
    private CodeResendCooldown cd() {
        if (cooldown == null) {
            cooldown = new CodeResendCooldown(redis);
        }
        return cooldown;
    }

    /** Yeniden kod isteme bekleme suresi (saniye): istemciye `resendAfterSeconds` olarak doner. */
    public long resendCooldownSeconds() {
        return cd().seconds();
    }

    /**
     * Kayit/e-posta dogrulama kodu beklemesini hesap aramasindan ONCE rezerve eder (var/yok fark etmez; zaten
     * sureliyse 429 RESEND_COOLDOWN). Ardindan {@link #issueAfterReserve} cagrilir.
     */
    public void reserveVerifyCooldown(String email) {
        cd().acquire(CodeResendCooldown.VERIFY, email);
    }

    /** Sifre sifirlama icin ayni (hesap var/yok fark etmeksizin) rezervasyon. */
    public void reserveResetCooldown(String email) {
        cd().acquire(CodeResendCooldown.RESET, email);
    }

    /** Gunluk e-posta kotasi doluysa genel 503 MAIL_QUOTA_EXHAUSTED (e-postadan bagimsiz: enumerasyon yok). */
    public void requireMailQuota() {
        mail.requireCodeQuota();
    }

    /** Hesap sahibine giden kod (2FA) icin: yalniz saglayici kotasi tamamen dolduysa 503 MAIL_QUOTA_EXHAUSTED. */
    public void requireAccountMailQuota() {
        mail.requireAccountCodeQuota();
    }

    /** Yeni kayit dogrulama kodu uretip gonderir. Ayni adrese bekleme suresi (180 sn) icinde tekrar gonderimi reddeder. */
    public void issue(String email, Lang lang) {
        issue(VERIFY, email, email, lang, true);
    }

    /** Bekleme {@link #reserveVerifyCooldown} ile ONCEDEN rezerve edilmisse kod gonderir (tekrar kontrol etmez). */
    public void issueAfterReserve(String email, Lang lang) {
        issue(VERIFY, email, email, lang, false);
    }

    /** Sifre sifirlama kodu uretip gonderir (ayri anahtar alani, ayni kurallar). */
    public void issueReset(String email, Lang lang) {
        issue(RESET, email, email, lang, true);
    }

    /** Bekleme {@link #reserveResetCooldown} ile ONCEDEN rezerve edilmisse sifirlama kodu gonderir. */
    public void issueResetAfterReserve(String email, Lang lang) {
        issue(RESET, email, email, lang, false);
    }

    /** Yonetici dogrulamasindan sonra e-posta dogrulama kodunu, sayaclarini, kilidini ve beklemeyi temizler. */
    public void clearVerify(String email) {
        redis.delete(List.of(VERIFY + ":" + email, VERIFY + ":att:" + email, VERIFY + ":lock:" + email));
        cd().release(CodeResendCooldown.VERIFY, email);
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

    /** Anahtar gecerli mi? Tuketmez (zayif parola reddi anahtari yakmasin). */
    public boolean checkResetToken(String email, String token) {
        String stored = redis.opsForValue().get("prt:" + email);
        return stored != null && MessageDigest.isEqual(stored.getBytes(StandardCharsets.UTF_8),
                Hashing.sha256(token).getBytes(StandardCharsets.UTF_8));
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

    /**
     * Iki faktorlu giris/etkinlestirme kodu ("tf" anahtar alani). {@code subject} e-posta degildir: giris icin
     * {@code <kullanici>:<challenge ozeti>}, etkinlestirme icin {@code <kullanici>:enable} (her biri ayri kod ve
     * sayac); kod {@code to} adresine gider. Yeniden gonderme beklemesi (180 sn) KONU basinadir (challenge ya da
     * etkinlestirme); geri kalan her kural (hash, 10 dk, 5 deneme, istemci kapsami, saatlik toplam) ayni kodu paylasir.
     */
    public void issueTwoFactor(String subject, String to, Lang lang) {
        issue(TWO_FACTOR, subject, to, lang, true);
    }

    /** Iki faktorlu bekleme rezervasyonu (cagiran diger kota/sinirlardan ONCE alir; sonra {@link #issueTwoFactorAfterReserve}). */
    public void reserveTwoFactorCooldown(String subject) {
        cd().acquire(CodeResendCooldown.TWO_FACTOR, subject);
    }

    /** Rezervasyon sonradan geri alinir (sinir/kota nedeniyle kod gonderilemedi). */
    public void releaseTwoFactorCooldown(String subject) {
        cd().release(CodeResendCooldown.TWO_FACTOR, subject);
    }

    public void issueTwoFactorAfterReserve(String subject, String to, Lang lang) {
        issue(TWO_FACTOR, subject, to, lang, false);
    }

    /** Iki faktorlu kod dogruysa true (ve kod tuketilir); kilit/limit asilirsa 429. `scope`: istemci anahtari. */
    public boolean verifyTwoFactor(String subject, String code, String scope) {
        return verify(TWO_FACTOR, subject, code, scope);
    }

    /** Bekleyen iki faktorlu kodu, sayaclarini ve kilidini siler (2FA kapatilirken / challenge iptalinde). */
    public void clearTwoFactor(String subject) {
        redis.delete(List.of(TWO_FACTOR + ":" + subject, TWO_FACTOR + ":att:" + subject,
                TWO_FACTOR + ":lock:" + subject, TWO_FACTOR + ":gatt:" + subject));
        clearScoped(TWO_FACTOR, subject);
        cd().release(CodeResendCooldown.TWO_FACTOR, subject);
    }

    private static String flowOf(String ns) {
        return RESET.equals(ns) ? CodeResendCooldown.RESET
                : TWO_FACTOR.equals(ns) ? CodeResendCooldown.TWO_FACTOR : CodeResendCooldown.VERIFY;
    }

    /** `email` hem anahtar hem varsayilan alici; iki faktorlu kodda anahtar kullanici kimligi, alici `to`. */
    private void issue(String ns, String email, String to, Lang lang, boolean acquireCooldown) {
        if (acquireCooldown) {
            cd().acquire(flowOf(ns), email); // zaten sureliyse 429 RESEND_COOLDOWN (Retry-After = kalan sure)
        }
        String code = String.format("%06d", random.nextInt(1_000_000));
        redis.opsForValue().set(ns + ":" + email, hash(email, code), CODE_TTL);
        redis.delete(List.of(ns + ":att:" + email, ns + ":lock:" + email));
        redis.delete(ns + ":gatt:" + email);
        // Kapsamli (e-posta, istemci) yanlis deneme sayac/kilitleri de sifirlanir (T-006): 5 yanlis denemeden sonra
        // gelen YENI kod, ayni istemcide dogru girilince 429'a takilmasin. Istemci anahtarlari kumede izlenir.
        clearScoped(ns, email);
        // Saatlik toplam yanlis deneme siniri asildiysa yeni kod kilidi ACMAZ (sayac sifirlama yolu kapali).
        if (totalWrong(ns, email) > MAX_HOURLY_WRONG) {
            redis.opsForValue().set(ns + ":lock:" + email, "1", LOCK_TTL);
        }
        try {
            if (RESET.equals(ns)) {
                mail.sendPasswordResetCode(to, code, (int) CODE_TTL.toMinutes(), lang);
            } else if (TWO_FACTOR.equals(ns)) {
                mail.sendTwoFactorCode(to, code, (int) CODE_TTL.toMinutes(), lang);
            } else {
                mail.sendVerificationCode(to, code, (int) CODE_TTL.toMinutes(), lang);
            }
        } catch (RuntimeException e) {
            // Gonderilemediyse bekleme suresi kullaniciyi cezalandirmasin.
            cd().release(flowOf(ns), email);
            redis.delete(ns + ":" + email);
            throw e;
        }
    }

    private void clearScoped(String ns, String email) {
        String setKey = ns + ":scopes:" + email;
        java.util.Set<String> scopes = redis.opsForSet().members(setKey);
        if (scopes != null && !scopes.isEmpty()) {
            List<String> keys = new java.util.ArrayList<>();
            for (String sc : scopes) {
                keys.add(ns + ":sc:" + email + ":" + sc + ":att");
                keys.add(ns + ":sc:" + email + ":" + sc + ":lock");
            }
            redis.delete(keys);
        }
        redis.delete(setKey);
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
        if (scoped != null) {
            // Yeni kod bu istemcinin sayac/kilidini sifirlayabilsin diye istemci anahtarini kumeye yaz (T-006)
            String setKey = ns + ":scopes:" + email;
            redis.opsForSet().add(setKey, scope);
            redis.expire(setKey, CODE_TTL.plus(LOCK_TTL));
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

    private String hash(String email, String code) {
        if (pepper == null || pepper.isEmpty()) {
            return Hashing.sha256(email + ":" + code);
        }
        try {
            javax.crypto.Mac mac = javax.crypto.Mac.getInstance("HmacSHA256");
            mac.init(new javax.crypto.spec.SecretKeySpec(pepper.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return java.util.HexFormat.of().formatHex(mac.doFinal((email + ":" + code).getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }
}
