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

    public ProdSettingsValidator(Environment env) {
        Result r = validate(env);
        r.warnings().forEach(w -> log.warn("Uretim ayari uyarisi: {}", w));
        if (!r.errors().isEmpty()) {
            throw new IllegalStateException("Uretim ayarlari gecersiz (" + r.errors().size() + " sorun):\n - "
                    + String.join("\n - ", r.errors()));
        }
        log.info("Uretim ayarlari dogrulandi (FCM: {}, e-posta: {})",
                notBlank(env, "app.fcm.credentials-file") ? "etkin" : "kapali (push gitmez)",
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
        }

        String jwt = env.getProperty("jwt.secret", "");
        if (jwt.length() < 32) {
            errors.add("JWT_SECRET zorunlu ve en az 32 karakter olmali");
        } else if (jwt.toLowerCase().contains(DEV_JWT_MARKER)) {
            errors.add("JWT_SECRET gelistirme varsayilani (dev-only...) olamaz; rastgele bir anahtar uretin");
        }

        if (!notBlank(env, "spring.security.user.password")) {
            errors.add("ADMIN_PASSWORD zorunlu (yonetici Basic auth sifresi)");
        } else if (env.getProperty("spring.security.user.password", "").length() < 12) {
            warnings.add("ADMIN_PASSWORD 12 karakterden kisa; daha guclu bir sifre onerilir");
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

        if (!notBlank(env, "app.fcm.credentials-file")) {
            warnings.add("FCM kimlik bilgisi yok: push bildirimleri gonderilmez (uygulama ici bildirimler calisir)");
        }
        return new Result(errors, warnings);
    }

    /** E-posta teslim edilebilirligi tutarliligi (yalniz MAIL_ENABLED=true iken). Ayrinti: docs/MAIL_DELIVERABILITY.md. */
    static void validateMailDeliverability(Environment env, List<String> errors, List<String> warnings) {
        if (!env.getProperty("app.mail.enabled", Boolean.class, false)) {
            return;
        }
        String from = env.getProperty("app.mail.from", "no-reply@bingol.edu.tr").trim();
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
                        + "hizalamasini (DMARC) saglayicida dogrulayin");
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

    private static boolean notBlank(Environment env, String key) {
        String v = env.getProperty(key);
        return v != null && !v.isBlank();
    }
}
