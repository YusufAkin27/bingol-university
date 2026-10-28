package edu.bingol.backend.mail;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.i18n.Lang;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    public MailService(MailOutboxRepository outbox, MailTransport transport, MailProperties props,
                       JsonMapper json, ApplicationEventPublisher events) {
        this.outbox = outbox;
        this.transport = transport;
        this.props = props;
        this.json = json;
        this.events = events;
    }

    /** Genel giris: sablonu degiskenleriyle kuyruga yazar. Gonderim arka planda yapilir. */
    public void enqueue(String to, MailTemplate template, Lang lang, Map<String, String> vars) {
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
        enqueue(to, MailTemplate.VERIFICATION_CODE, lang, vars("code", code, "minutes", String.valueOf(minutes)));
    }

    public void sendPasswordResetCode(String to, String code, int minutes, Lang lang) {
        enqueue(to, MailTemplate.PASSWORD_RESET_CODE, lang, vars("code", code, "minutes", String.valueOf(minutes)));
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
            return true;
        } catch (Exception e) {
            log.error("E-posta gonderilemedi ({}): {}", MailAddresses.mask(to), e.toString());
            return false;
        }
    }

    /** Kuyruktaki e-postalarin duruma gore sayilari. */
    public QueueStats queueStats() {
        return new QueueStats(outbox.countByStatus(MailStatus.PENDING), outbox.countByStatus(MailStatus.FAILED),
                outbox.countByStatus(MailStatus.SENT), outbox.countByStatus(MailStatus.DEAD));
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
