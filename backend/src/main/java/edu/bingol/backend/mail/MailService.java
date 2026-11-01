package edu.bingol.backend.mail;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.i18n.Lang;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;

/**
 * E-posta kuyruguna yazma arayuzu. Gonderim zamanlanmis {@link MailQueueWorker} ile yapilir; cagiranlar
 * SMTP gecikmesinden ve gecici hatalardan etkilenmez. Kuyruga yazma basarisiz olursa MAIL_UNAVAILABLE firlatir.
 */
@Service
public class MailService {

    private static final Logger log = LoggerFactory.getLogger(MailService.class);
    private static final int MAX_VARS_JSON = 4000;

    /** Kuyruk durum sayilari (yonetim/izleme icin). */
    public record QueueStats(long pending, long failed, long sent, long dead) {
    }

    private final MailOutboxRepository outbox;
    private final MailTransport transport;
    private final MailProperties props;
    private final JsonMapper json;
    private final ApplicationEventPublisher events;
    private final MailDailyQuota quota;

    @Autowired
    public MailService(MailOutboxRepository outbox, MailTransport transport, MailProperties props,
                       JsonMapper json, ApplicationEventPublisher events, MailDailyQuota quota) {
        this.quota = quota;
        this.outbox = outbox;
        this.transport = transport;
        this.props = props;
        this.json = json;
        this.events = events;
    }

    /** Eski imza (geriye uyumluluk): kota korumasi olmadan. */
    public MailService(MailOutboxRepository outbox, MailTransport transport, MailProperties props,
                       JsonMapper json, ApplicationEventPublisher events) {
        this(outbox, transport, props, json, events, null);
    }

    /**
     * Kod (kayit/sifre) gondermeden once cagrilir: gunluk kota tamamen dolduysa 503 MAIL_QUOTA_EXHAUSTED.
     * Karar GLOBALDIR (e-postadan bagimsiz), bu yuzden hesabin varligini sizdirmaz; cagiran, hesap sorgusundan
     * ONCE cagirmalidir. Kota korumasi kapaliyken (limit 0) veya e-posta kapaliyken hicbir sey yapmaz.
     * Tur, gecerli istek yolundan cikarilir (sifre sifirlama uclari = PASSWORD_RESET): bkz. {@link #requireCodeQuota(MailDailyQuota.CodeKind)}.
     */
    public void requireCodeQuota() {
        requireCodeQuota(quota == null ? MailDailyQuota.CodeKind.REGISTRATION : quota.currentRequestKind());
    }

    /**
     * Kimliksiz kod istegi korumasi (hepsi hesap sorgusundan ONCE ve e-postadan bagimsiz, yani varlik sizdirmaz):
     * (1) istemci IP'si basina gunluk kod istegi sayaci (IPv6 /64) -> 429; (2) kimliksiz kod butcesi:
     * kayit/destek gunluk kotanin {@code app.mail.public-code-share} (0.6) payina, sifre sifirlama
     * {@code reset-code-share} (0.85) payina kadar; kalan pay gercek kullanici/guvenlik postalarina rezervdir -> 503;
     * (3) saglayici kotasi tamamen doldu -> 503 MAIL_QUOTA_EXHAUSTED.
     */
    public void requireCodeQuota(MailDailyQuota.CodeKind kind) {
        if (quota == null || !props.enabled()) {
            return;
        }
        String ip = quota.currentRequestIp();
        if (ip != null) {
            quota.checkRequestIp(ip);
        }
        if (quota.exhausted() || quota.publicExhausted(kind)) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_QUOTA_EXHAUSTED",
                    "Şu anda doğrulama kodu gönderemiyoruz, lütfen daha sonra tekrar deneyin.");
        }
    }

    /** Genel giris: sablonu degiskenleriyle kuyruga yazar. Gonderim arka planda yapilir. */
    public void enqueue(String to, MailTemplate template, Lang lang, Map<String, String> vars) {
        enqueue(to, template, lang, vars, null);
    }

    /**
     * Kampanya postasi: kuyruk satirina kampanya kimligi yazilir; kampanya iptal edilince henuz gonderilmemis
     * satirlar SKIPPED olur (campaignId null = islemsel / kampanyasiz).
     */
    public void enqueue(String to, MailTemplate template, Lang lang, Map<String, String> vars, Long campaignId) {
        if (!MailAddresses.isPlausible(to)) {
            log.warn("Gecersiz alici adresi, e-posta kuyruga alinmadi: {}", MailAddresses.mask(to));
            throw mailUnavailable();
        }
        try {
            MailOutbox m = new MailOutbox();
            m.setToAddress(to);
            m.setTemplate(template);
            m.setLang(lang.code());
            m.setVarsJson(toJson(vars));
            m.setPriority(MailCategory.of(template).priority());
            m.setCampaignId(campaignId);
            m.setCreatedAt(Instant.now());
            m.setNextAttemptAt(m.getCreatedAt());
            outbox.save(m);
            events.publishEvent(new MailQueued());
        } catch (Exception e) {
            log.error("E-posta kuyruga yazilamadi ({}): {}", MailAddresses.mask(to), e.toString());
            throw mailUnavailable();
        }
    }

    public void sendVerificationCode(String to, String code, int minutes, Lang lang) {
        if (!allowPublicCode(to)) {
            return;
        }
        enqueue(to, MailTemplate.VERIFICATION_CODE, lang, vars("code", code, "minutes", String.valueOf(minutes)));
        recordPublicCode();
    }

    public void sendPasswordResetCode(String to, String code, int minutes, Lang lang) {
        if (!allowPublicCode(to)) {
            return;
        }
        enqueue(to, MailTemplate.PASSWORD_RESET_CODE, lang, vars("code", code, "minutes", String.valueOf(minutes)));
        recordPublicCode();
    }

    /**
     * Iki faktorlu giris/etkinlestirme kodu. Hesap sahibine, sifre dogrulandiktan sonra gider (kimliksiz kod akisi
     * degildir): kimliksiz kod butcesi ve alici basina gunluk "sessiz atlama" UYGULANMAZ; hiz siniri cagiranda
     * (TwoFactorService) kullanici basinadir.
     */
    public void sendTwoFactorCode(String to, String code, int minutes, Lang lang) {
        enqueue(to, MailTemplate.TWO_FACTOR_CODE, lang, vars("code", code, "minutes", String.valueOf(minutes)));
    }

    /**
     * Alici basina gunluk kod postasi siniri (app.mail.max-codes-per-email-per-day). Asilirsa posta SESSIZCE
     * gonderilmez (genel cevap korunur: hesap varligi sizmaz; kod zaten e-postaya ulasmamis olur) ve log'lanir.
     */
    private boolean allowPublicCode(String to) {
        if (quota == null || !props.enabled() || quota.allowRecipientCode(to)) {
            return true;
        }
        log.warn("Alici basina gunluk kod postasi siniri asildi, posta gonderilmedi: {}", MailAddresses.mask(to));
        return false;
    }

    private void recordPublicCode() {
        if (quota != null && props.enabled()) {
            quota.recordPublicCode();
        }
    }

    public void sendAccountDeleted(String to, Lang lang) {
        enqueue(to, MailTemplate.ACCOUNT_DELETED, lang, Map.of());
    }

    public void sendNewLoginAlert(String to, String device, String time, Lang lang) {
        enqueue(to, MailTemplate.SECURITY_NEW_LOGIN, lang, vars("device", device, "time", time));
    }

    public void sendPasswordChanged(String to, String time, Lang lang) {
        enqueue(to, MailTemplate.SECURITY_PASSWORD_CHANGED, lang, vars("time", time));
    }

    /** 2FA guvenlik bildirimi: `message` alicinin dilinde hazir metindir (bkz. TwoFactorNotifier). */
    public void sendTwoFactorNotice(String to, String message, Lang lang) {
        enqueue(to, MailTemplate.SECURITY_TWO_FACTOR_NOTICE, lang, vars("message", message));
    }

    /**
     * Hesap sahibine giden kod postasi icin (2FA girisi/etkinlestirme): yalniz saglayici gunluk kotasi TAMAMEN
     * dolduysa 503 MAIL_QUOTA_EXHAUSTED. Kimliksiz kod butcesi/IP sayaci uygulanmaz (sifresi dogrulanmis kullanici);
     * kota doluyken kod kuyrukta takilip kullaniciyi kilitli birakmasin diye istek baslarken reddedilir.
     */
    public void requireAccountCodeQuota() {
        if (quota != null && props.enabled() && quota.exhausted()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_QUOTA_EXHAUSTED",
                    "Şu anda doğrulama kodu gönderemiyoruz, lütfen daha sonra tekrar deneyin.");
        }
    }

    public void sendAnnouncement(String to, String heading, String message, Lang lang) {
        enqueue(to, MailTemplate.ANNOUNCEMENT, lang, vars("heading", heading, "message", message));
    }

    /**
     * Kuyruk disi, aninda gonderim (destek talebi gibi sonucu cagirana donen akislar icin). Servis sozlesmesi:
     * istisna sizdirmaz, basari bool doner. E-posta kapaliyken govde log'a yazilir (yalnizca gelistirme).
     */
    public boolean sendRich(String to, String subject, String plain, String html, String replyTo) {
        try {
            if (!props.enabled()) {
                transport.logInsteadOfSending(to, subject, plain);
                return true;
            }
            transport.send(to, subject, plain, html, replyTo);
            if (quota != null) {
                quota.recordSent(); // kuyruk disi gonderimler de saglayici kotasindan sayilir
            }
            return true;
        } catch (Exception e) {
            log.error("E-posta gonderilemedi ({}): {}", MailAddresses.mask(to), e.toString());
            return false;
        }
    }

    /**
     * Kimliksiz (hesapsiz) akislardaki ANLIK kod postasi (herkese acik destek dogrulama kodu): saglayici kotasi ve
     * kimliksiz kod butcesi (SUPPORT) kontrol edilir, alici basina gunluk sinir uygulanir, basarili gonderim hem
     * genel sayaca hem kimliksiz sayaca yazilir. Kota/limit durumunda ApiException/RateLimitedException firlatir.
     */
    public boolean sendPublicCode(String to, String subject, String plain, String html, String replyTo) {
        if (quota != null && props.enabled()
                && (quota.exhausted() || quota.publicExhausted(MailDailyQuota.CodeKind.SUPPORT))) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_QUOTA_EXHAUSTED",
                    "Şu anda doğrulama kodu gönderemiyoruz, lütfen daha sonra tekrar deneyin.");
        }
        if (quota != null && props.enabled() && !quota.allowRecipientCode(to)) {
            throw new edu.bingol.backend.common.RateLimitedException(3600);
        }
        boolean ok = sendRich(to, subject, plain, html, replyTo);
        if (ok) {
            recordPublicCode();
        }
        return ok;
    }

    /**
     * Herkese acik (hesapsiz) destek dogrulama kodunu KUYRUGA yazar; SMTP cagiran iplikte konusulmaz (yavas SMTP'de
     * Tomcat is parcaciklari tukenmesin). {@link #sendPublicCode} ile ayni korumalar: saglayici kotasi ya da kimliksiz
     * kod butcesi (SUPPORT) doluysa 503 MAIL_QUOTA_EXHAUSTED, alici basina gunluk sinir asildiysa 429; kod postasi 10
     * dk sonra bayatlar ve gonderilmez ({@code CODE_MAIL_MAX_AGE}). Kuyruga yazilamazsa 503 MAIL_UNAVAILABLE.
     * Gonderim sonucu cagirana donmez (hata kuyrukta yeniden denenir).
     */
    public void enqueuePublicCode(String to, String code, int minutes, Lang lang) {
        if (quota != null && props.enabled()) {
            if (quota.exhausted() || quota.publicExhausted(MailDailyQuota.CodeKind.SUPPORT)) {
                throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_QUOTA_EXHAUSTED",
                        "Şu anda doğrulama kodu gönderemiyoruz, lütfen daha sonra tekrar deneyin.");
            }
            if (!quota.allowRecipientCode(to)) {
                throw new edu.bingol.backend.common.RateLimitedException(3600);
            }
        }
        enqueue(to, MailTemplate.SUPPORT_CODE, lang, vars("code", code, "minutes", String.valueOf(minutes)));
        recordPublicCode();
    }

    /** Kuyruktaki e-postalarin duruma gore sayilari. */
    public QueueStats queueStats() {
        return new QueueStats(outbox.countByStatus(MailStatus.PENDING), outbox.countByStatus(MailStatus.FAILED),
                outbox.countByStatus(MailStatus.SENT), outbox.countByStatus(MailStatus.DEAD));
    }

    /** Saglik gostergesi icin dar sayim (SENT sayilmaz: buyuk tabloda pahali ve gostergede gereksiz). */
    public record HealthStats(long pending, long failed, long dead) {
    }

    public HealthStats healthStats() {
        return new HealthStats(outbox.countByStatus(MailStatus.PENDING), outbox.countByStatus(MailStatus.FAILED),
                outbox.countByStatus(MailStatus.DEAD));
    }

    private String toJson(Map<String, String> vars) {
        Map<String, String> clean = new LinkedHashMap<>();
        vars.forEach((k, v) -> clean.put(k, v == null ? "" : v));
        String out = json.writeValueAsString(clean);
        if (out.length() > MAX_VARS_JSON) {
            throw new IllegalArgumentException("E-posta degiskenleri cok uzun");
        }
        return out;
    }

    private static Map<String, String> vars(String... kv) {
        Map<String, String> m = new LinkedHashMap<>();
        for (int i = 0; i < kv.length; i += 2) {
            m.put(kv[i], kv[i + 1]);
        }
        return m;
    }

    private static ApiException mailUnavailable() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_UNAVAILABLE",
                "Doğrulama e-postası şu anda gönderilemiyor. Lütfen daha sonra tekrar deneyin.");
    }
}
