package edu.bingol.backend.config;

import java.util.ArrayList;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

/**
 * Uretim (prod) profilinde zorunlu ayarlari acilista dogrular; eksik/guvensizse uygulama ANLASILIR bir
 * hata ile baslamaz. Sir degerleri hicbir zaman log'a ya da hata metnine yazilmaz (yalnizca anahtar adi).
 */
@Component
@Profile("prod")
public class ProdSettingsValidator {

    private static final Logger log = LoggerFactory.getLogger(ProdSettingsValidator.class);
    static final String DEV_JWT_MARKER = "dev-only";

    /**
     * .env.example / .env.prod.example ve belgelerdeki yer tutucu parcalari (kucuk harf, alt dize eslesmesi). Bu
     * dizeler depoda herkesce okunur: oldugu gibi birakilirsa sir bilinen bir degerdir (JWT sahteciligi = ADMIN).
     */
    static final List<String> PLACEHOLDERS = List.of("dev-only", "change-me", "changeme", "change_me", "degistir",
            "yer_tutucu", "yertutucu", "en-az-32", "replace-me", "replace_me", "placeholder", "your-secret",
            "your_secret", "example-secret");
    static final int MIN_ADMIN_PASSWORD = 12;
    static final int MIN_DISTINCT_JWT_CHARS = 10;

    public ProdSettingsValidator(Environment env) {
        Result r = validate(env);
        r.warnings().forEach(w -> log.warn("Uretim ayari uyarisi: {}", w));
        if (!r.errors().isEmpty()) {
            throw new IllegalStateException("Uretim ayarlari gecersiz (" + r.errors().size() + " sorun):\n - "
                    + String.join("\n - ", r.errors()));
        }
        log.info("Uretim ayarlari dogrulandi (FCM: {}, e-posta: {})",
                hasFcmCredentials(env) ? "etkin" : "kapali (push gitmez)",
                env.getProperty("app.mail.enabled", Boolean.class, false) ? "etkin" : "kapali");
    }

    public record Result(List<String> errors, List<String> warnings) {
    }

    /** Saf dogrulama: ortami okur, yan etkisi yoktur (test edilebilir). */
    static Result validate(Environment env) {
        List<String> errors = new ArrayList<>();
        List<String> warnings = new ArrayList<>();

        if (!notBlank(env, "spring.datasource.password")) {
            errors.add("DB_PASSWORD zorunlu (bos olamaz)");
        } else if ("bingol".equals(env.getProperty("spring.datasource.password"))) {
            errors.add("DB_PASSWORD gelistirme varsayilani 'bingol' olamaz");
        } else if (isPlaceholder(env.getProperty("spring.datasource.password"))) {
            errors.add("DB_PASSWORD ornek/yer tutucu deger olamaz; rastgele bir sifre uretin");
        }

        String jwt = env.getProperty("jwt.secret", "");
        if (jwt.length() < 32) {
            errors.add("JWT_SECRET zorunlu ve en az 32 karakter olmali");
        } else if (jwt.toLowerCase().contains(DEV_JWT_MARKER)) {
            errors.add("JWT_SECRET gelistirme varsayilani (dev-only...) olamaz; rastgele bir anahtar uretin");
        } else if (isPlaceholder(jwt)) {
            errors.add("JWT_SECRET ornek/yer tutucu deger olamaz (.env.example); rastgele bir anahtar uretin");
        } else if (jwt.chars().distinct().count() < MIN_DISTINCT_JWT_CHARS) {
            errors.add("JWT_SECRET cok dusuk cesitlilikte (tekrarli karakterler); rastgele bir anahtar uretin");
        }

        // Basic auth yalniz acikken ADMIN_PASSWORD gerekir (prod varsayilani kapali; yalniz JWT ADMIN kullanilir).
        // Dogrulayicinin saf testleri icin varsayilan "acik": ayar verilmediyse sifre denetlenir (guvenli taraf).
        if (env.getProperty("app.security.admin-basic.enabled", Boolean.class, true)) {
            String adminPw = env.getProperty("spring.security.user.password", "");
            if (adminPw.isBlank()) {
                errors.add("ADMIN_PASSWORD zorunlu (yonetici Basic auth sifresi; Basic auth kullanmayacaksaniz "
                        + "app.security.admin-basic.enabled=false)");
            } else if (adminPw.length() < MIN_ADMIN_PASSWORD) {
                errors.add("ADMIN_PASSWORD en az " + MIN_ADMIN_PASSWORD + " karakter olmali");
            } else if (isPlaceholder(adminPw)) {
                errors.add("ADMIN_PASSWORD ornek/yer tutucu deger olamaz; rastgele bir sifre uretin");
            }
        }

        // Sifreleme ana anahtarlari verilmisse yer tutucu olamaz (bos olma durumunu app.crypto.require-keys denetler).
        for (String key : List.of("app.crypto.master-keys")) {
            String v = env.getProperty(key, "");
            if (!v.isBlank() && isPlaceholder(v)) {
                errors.add("CRYPTO_MASTER_KEYS ornek/yer tutucu deger olamaz; `openssl rand -base64 32` ile uretin");
            }
        }

        String cors = env.getProperty("app.cors.allowed-origins", "");
        if (cors.isBlank()) {
            errors.add("CORS_ORIGINS zorunlu (virgullu https kokenler)");
        } else if (cors.contains("*")) {
            errors.add("CORS_ORIGINS uretimde '*' icermemeli");
        } else if (cors.contains("localhost")) {
            warnings.add("CORS_ORIGINS localhost iceriyor; uretim icin gercek alan adlarini verin");
        }

        if (!env.getProperty("app.mail.enabled", Boolean.class, false)) {
            if (env.getProperty("app.mail.allow-log-only", Boolean.class, false)) {
                warnings.add("MAIL_ENABLED=false (allow-log-only): dogrulama kodlari e-posta yerine log'a yazilir");
            } else {
                errors.add("MAIL_ENABLED=true ve MAIL_* zorunlu; kodlarin log'a yazilmasi icin bilincli olarak "
                        + "app.mail.allow-log-only=true verin");
            }
        } else if (!notBlank(env, "spring.mail.host") || "localhost".equals(env.getProperty("spring.mail.host"))) {
            errors.add("MAIL_ENABLED=true iken MAIL_HOST zorunlu");
        }
        validateMailDeliverability(env, errors, warnings);

        // Cihaz kimligi HMAC anahtari istege bagli (bos = JWT sirrindan turetilir); verilirse yeterince uzun olmali.
        String hmac = env.getProperty("app.security.device-hmac-key", "");
        if (!hmac.isBlank() && hmac.length() < 32) {
            errors.add("DEVICE_HMAC_KEY verilirse en az 32 karakter olmali");
        }

        if (!hasFcmCredentials(env)) {
            warnings.add("FCM kimlik bilgisi yok: push bildirimleri gonderilmez (uygulama ici bildirimler calisir)");
        }
        validateOpsWarnings(env, warnings);
        return new Result(errors, warnings);
    }

    /**
     * Isletme UYARILARI (hata DEGIL, acilis engellenmez): uzak yedek, ikinci FULL yonetici, Sentry. Hepsi docker-compose.prod.yml'in
     * backend'e ilettigi degiskenlerden okunur (BACKUP_REMOTE yedek servisiyle ayni degerdir).
     */
    static void validateOpsWarnings(Environment env, List<String> warnings) {
        // A8-01: yedekler yalniz sunucu diskindeyse disk/sunucu kaybi = tum yedeklerin kaybi (tek hata noktasi)
        if (!notBlank(env, "BACKUP_REMOTE")) {
            warnings.add("BACKUP_REMOTE bos: yedekler YALNIZ sunucu diskinde; sunucu/disk kaybi tum yedekleri de yok eder. "
                    + "Farkli saglayicida sifreli (rclone crypt) uzak hedef verin (docs/BACKUP_RESTORE.md bolum 11)");
        }
        // A14-17: tek FULL yonetici varken iki kisi onayi (FULL ata/dusur) kilitlenir; panelden ikinci FULL yaratilamaz
        if (countAddresses(env.getProperty("app.admin.emails", "")) < 2) {
            warnings.add("ADMIN_EMAILS en az 2 adres icermeli: tek FULL yonetici iken iki kisi onayi gerektiren "
                    + "islemler (FULL ata/dusur) kilitlenir (docs/DEPLOY.md)");
        }
        // K-31: Sentry kullanilmayacaksa DSN bos kalmali; kullanilacaksa AB bolgesi + send-default-pii=false + tedarikci listesi
        if (notBlank(env, "sentry.dsn")) {
            warnings.add("SENTRY_DSN dolu: hata verisi ucuncu tarafa gider; AB bolgesi, send-default-pii=false ve "
                    + "tedarikci/KVKK listesi dogrulanmali (docs/DEPLOY.md), kullanilmayacaksa bos birakin");
        }
    }

    /** Virgullu adres listesindeki bos olmayan, tekrarsiz girdi sayisi (buyuk/kucuk harf duyarsiz). */
    static int countAddresses(String csv) {
        if (csv == null || csv.isBlank()) {
            return 0;
        }
        java.util.Set<String> seen = new java.util.HashSet<>();
        for (String part : csv.split(",")) {
            String v = part.trim().toLowerCase(java.util.Locale.ROOT);
            if (!v.isEmpty()) {
                seen.add(v);
            }
        }
        return seen.size();
    }

    /** FCM kimligi: dosya yolu ya da JSON (app.fcm.credentials-json / FCM_CREDENTIALS_JSON); FcmConfig ile ayni kaynaklar. */
    static boolean hasFcmCredentials(Environment env) {
        return notBlank(env, "app.fcm.credentials-file") || notBlank(env, "app.fcm.credentials-json")
                || notBlank(env, "FCM_CREDENTIALS_JSON");
    }

    /** E-posta teslim edilebilirligi tutarliligi (yalniz MAIL_ENABLED=true iken). Ayrinti: docs/MAIL_DELIVERABILITY.md. */
    static void validateMailDeliverability(Environment env, List<String> errors, List<String> warnings) {
        if (!env.getProperty("app.mail.enabled", Boolean.class, false)) {
            return;
        }
        String from = MailProperties.addressOf(env.getProperty("app.mail.from", "no-reply@bingol.edu.tr"));
        int at = from.lastIndexOf('@');
        String domain = at < 0 ? "" : from.substring(at + 1).toLowerCase(java.util.Locale.ROOT);
        if (from.isEmpty() || at < 1 || domain.isEmpty()) {
            errors.add("MAIL_FROM zorunlu ve ad@alanadi bicimde olmali");
        } else if (domain.equals("localhost") || domain.endsWith(".local") || domain.endsWith(".invalid")
                || domain.equals("example.com")) {
            errors.add("MAIL_FROM alan adi gercek ve DNS'te SPF/DKIM/DMARC kayitli olmali (su an: " + domain + ")");
        } else {
            String user = env.getProperty("spring.mail.username", "");
            int uat = user.lastIndexOf('@');
            if (uat > 0 && !user.substring(uat + 1).equalsIgnoreCase(domain)
                    && !domain.endsWith("." + user.substring(uat + 1).toLowerCase(java.util.Locale.ROOT))) {
                warnings.add("MAIL_FROM alan adi (" + domain + ") SMTP kullanici alan adindan farkli; DKIM/SPF "
                        + "hizalamasini (DMARC) saglayicida dogrulayin (Brevo/SES gibi servislerde bu uyari beklenir: SMTP kullanicisi "
                        + "alan adi degildir; alan adi saglayicida dogrulanmissa sorun yok, bkz. docs/MAIL_DELIVERABILITY.md bolum 9)");
            }
        }
        boolean tls = env.getProperty("spring.mail.properties.mail.smtp.starttls.required", Boolean.class, false)
                || env.getProperty("spring.mail.properties.mail.smtp.ssl.enable", Boolean.class, false);
        if (!tls) {
            warnings.add("SMTP icin TLS zorunlu degil: MAIL_REQUIRE_TLS=true (veya port 465 icin MAIL_SSL=true) onerilir");
        }
        String unsub = env.getProperty("app.mail.unsubscribe-base-url", "");
        if (unsub.isBlank() || unsub.contains("localhost") || !unsub.startsWith("https://")) {
            warnings.add("PUBLIC_WEB_URL https ve herkese acik olmali: duyuru maillerindeki abonelikten cikma baglantisi "
                    + "bu adresi kullanir (su an gecersiz/localhost ise duyurular gonderilmez)");
        }
        if (env.getProperty("app.mail.max-per-minute", Integer.class, 30) <= 0) {
            warnings.add("MAIL_MAX_PER_MINUTE sinirsiz: yeni alan adinda isinma (warm-up) plani uygulayin");
        }
    }

    /** Deger bilinen bir ornek/yer tutucu parcasini iceriyor mu (buyuk/kucuk harf duyarsiz). */
    static boolean isPlaceholder(String value) {
        if (value == null) {
            return false;
        }
        String v = value.toLowerCase(java.util.Locale.ROOT);
        for (String p : PLACEHOLDERS) {
            if (v.contains(p)) {
                return true;
            }
        }
        return false;
    }

    private static boolean notBlank(Environment env, String key) {
        String v = env.getProperty(key);
        return v != null && !v.isBlank();
    }
}
