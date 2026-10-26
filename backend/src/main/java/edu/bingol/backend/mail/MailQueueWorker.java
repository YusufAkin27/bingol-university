package edu.bingol.backend.mail;

import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.i18n.Lang;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.annotation.PreDestroy;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

/**
 * E-posta kuyrugunu isler. Birden fazla sunucuda guvenlidir (claimDue: SKIP LOCKED + kira).
 * Hata durumunda ustel geri cekilmeyle yeniden dener; limit asilinca DEAD. Servis sozlesmesi: istisna sizdirmaz.
 */
@Component
public class MailQueueWorker {

    private static final Logger log = LoggerFactory.getLogger(MailQueueWorker.class);
    /** Bir turda alinan kaydin baska sunucularca tekrar alinmamasi icin kira suresi. */
    private static final Duration LEASE = Duration.ofMinutes(5);
    private static final Duration RETENTION = Duration.ofDays(30);
    /** Kodlu sablonlar bu sureden sonra gonderilmez: kod (VerificationService.CODE_TTL) zaten gecersizdir. */
    static final Duration CODE_MAIL_MAX_AGE = Duration.ofMinutes(10);
    private static final TypeReference<Map<String, String>> VARS_TYPE = new TypeReference<>() {
    };

    private final MailOutboxRepository outbox;
    private final MailRenderer renderer;
    private final MailTransport transport;
    private final MailProperties props;
    private final JsonMapper json;
    private final MeterRegistry metrics;
    private final ExecutorService nudgeExecutor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "mail-nudge");
        t.setDaemon(true);
        return t;
    });

    public MailQueueWorker(MailOutboxRepository outbox, MailRenderer renderer, MailTransport transport,
                           MailProperties props, JsonMapper json, MeterRegistry metrics) {
        this.outbox = outbox;
        this.renderer = renderer;
        this.transport = transport;
        this.props = props;
        this.json = json;
        this.metrics = metrics;
    }

    /** Yeni e-posta yazilinca (transaction commit'inden sonra) beklemeden bir tur calistirir. */
    @TransactionalEventListener(fallbackExecution = true)
    void onQueued(MailQueued event) {
        try {
            nudgeExecutor.execute(this::processDue);
        } catch (RuntimeException e) {
            log.debug("Mail isleyici tetiklenemedi, zamanlayici alacak: {}", e.toString());
        }
    }

    @Scheduled(fixedDelayString = "${app.mail.queue-poll-ms:5000}")
    public void poll() {
        processDue();
    }

    /** 30 gunden eski her durumdaki kayitlari siler (her gece). */
    @Scheduled(cron = "0 40 3 * * *", zone = "Europe/Istanbul")
    public void purgeOld() {
        try {
            int n = outbox.deleteFinishedBefore(Instant.now().minus(RETENTION));
            if (n > 0) {
                log.info("{} eski e-posta kaydi silindi", n);
            }
        } catch (Exception e) {
            log.warn("E-posta kuyruk temizligi basarisiz: {}", e.toString());
        }
    }

    /** Zamani gelen e-postalari bir parti halinde isler. */
    void processDue() {
        try {
            Instant now = Instant.now();
            List<Long> ids = outbox.claimDue(now, now.plus(LEASE), props.batchSize());
            ids.forEach(this::process);
        } catch (Exception e) {
            log.error("Mail kuyrugu islenemedi: {}", e.toString());
        }
    }

    private void process(Long id) {
        MailOutbox m = outbox.findById(id).orElse(null);
        if (m == null || (m.getStatus() != MailStatus.PENDING && m.getStatus() != MailStatus.FAILED)) {
            return;
        }
        if (isStaleCodeMail(m)) {
            m.markExpired("kod suresi doldu, gonderilmedi");
            metrics.counter("mail.queue.expired").increment();
            outbox.save(m);
            return;
        }
        try {
            deliver(m);
            m.markSent(Instant.now());
            metrics.counter("mail.queue.sent").increment();
        } catch (Exception e) {
            recordFailure(m, e);
        }
        outbox.save(m);
    }

    private static boolean isStaleCodeMail(MailOutbox m) {
        return (m.getTemplate() == MailTemplate.VERIFICATION_CODE || m.getTemplate() == MailTemplate.PASSWORD_RESET_CODE)
                && m.getCreatedAt() != null && m.getCreatedAt().isBefore(Instant.now().minus(CODE_MAIL_MAX_AGE));
    }

    private void deliver(MailOutbox m) throws Exception {
        Map<String, String> vars = json.readValue(m.getVarsJson(), VARS_TYPE);
        MailRenderer.Rendered mail = renderer.render(m.getTemplate(), Lang.of(m.getLang()), vars);
        if (props.enabled()) {
            transport.send(m.getToAddress(), mail.subject(), mail.text(), mail.html(), null);
        } else {
            logForDevelopment(m, mail, vars);
        }
    }

    /** Yalnizca gelistirme (CLAUDE.md kural 7): kod e-posta kapaliyken log'a yazilir. */
    private void logForDevelopment(MailOutbox m, MailRenderer.Rendered mail, Map<String, String> vars) {
        if (m.getTemplate() == MailTemplate.VERIFICATION_CODE) {
            log.warn("[DEV] {} icin dogrulama kodu: {}", m.getToAddress(), vars.get("code"));
        } else {
            transport.logInsteadOfSending(m.getToAddress(), mail.subject(), mail.text());
        }
    }

    private void recordFailure(MailOutbox m, Exception e) {
        String error = e.getClass().getSimpleName() + ": " + e.getMessage();
        m.markFailed(error, Instant.now(), props.maxAttempts());
        metrics.counter("mail.queue.failed").increment();
        if (m.getStatus() == MailStatus.DEAD) {
            metrics.counter("mail.queue.dead").increment();
            log.error("E-posta {} deneme sonunda gonderilemedi (DEAD) id={} alici={} sablon={}",
                    m.getAttempts(), m.getId(), MailAddresses.mask(m.getToAddress()), m.getTemplate());
        } else {
            log.warn("E-posta gonderilemedi id={} alici={} deneme={} hata={}", m.getId(),
                    MailAddresses.mask(m.getToAddress()), m.getAttempts(), e.getClass().getSimpleName());
        }
    }

    @PreDestroy
    void shutdown() {
        nudgeExecutor.shutdown();
    }
}
