package edu.bingol.backend.mail;

import edu.bingol.backend.config.MailProperties;
import edu.bingol.backend.config.SchedulerLock;
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
import org.springframework.beans.factory.annotation.Autowired;
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

    private final MailSuppressionService suppression;
    private final UnsubscribeTokens tokens;
    private final SchedulerLock schedulerLock;
    private final MailDailyQuota quota;

    @Autowired
    public MailQueueWorker(MailOutboxRepository outbox, MailRenderer renderer, MailTransport transport,
                           MailProperties props, JsonMapper json, MeterRegistry metrics,
                           MailSuppressionService suppression, UnsubscribeTokens tokens, SchedulerLock schedulerLock,
                           MailDailyQuota quota) {
        this.quota = quota;
        this.outbox = outbox;
        this.renderer = renderer;
        this.transport = transport;
        this.props = props;
        this.json = json;
        this.metrics = metrics;
        this.suppression = suppression;
        this.tokens = tokens;
        this.schedulerLock = schedulerLock;
    }

    /** Eski 9 parametreli imza (geriye uyumluluk): gunluk kota korumasi olmadan. */
    public MailQueueWorker(MailOutboxRepository outbox, MailRenderer renderer, MailTransport transport,
                           MailProperties props, JsonMapper json, MeterRegistry metrics,
                           MailSuppressionService suppression, UnsubscribeTokens tokens, SchedulerLock schedulerLock) {
        this(outbox, renderer, transport, props, json, metrics, suppression, tokens, schedulerLock, null);
    }

    /** Eski imza (geriye uyumluluk): duyuru bastirma/abonelik ve dagitik kilit olmadan; yalniz islemsel akis. */
    public MailQueueWorker(MailOutboxRepository outbox, MailRenderer renderer, MailTransport transport,
                           MailProperties props, JsonMapper json, MeterRegistry metrics) {
        this(outbox, renderer, transport, props, json, metrics, null, null, null, null);
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
        // Cok ornekte yalniz biri temizlesin (poll() icin kilit gerekmez: claimDue SKIP LOCKED ile zaten atomik)
        if (schedulerLock == null) {
            doPurge();
        } else {
            schedulerLock.tryRun("mail-purge", Duration.ofMinutes(10), this::doPurge);
        }
    }

    private void doPurge() {
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
            // Islemsel mailler her zaman once ve sinirsiz
            List<Long> ids = outbox.claimDue(now, now.plus(LEASE), props.batchSize());
            ids.forEach(this::process);
            // Duyurular: dakika basina sinir (isinma/itibar korumasi); butce DB'den hesaplanir (cok ornekte ortak)
            int budget = announcementBudget(now);
            if (budget > 0) {
                outbox.claimDueAnnouncements(now, now.plus(LEASE), budget).forEach(this::process);
            }
        } catch (Exception e) {
            log.error("Mail kuyrugu islenemedi: {}", e.toString());
        }
    }

    /** Bu turda alinabilecek duyuru sayisi: min(batch, maxPerMinute - son dakikada gonderilen). */
    int announcementBudget(Instant now) {
        int batch = props.batchSize();
        if (props.maxPerMinute() <= 0) {
            return batch;
        }
        long sent = outbox.countByPriorityGreaterThanAndStatusAndSentAtAfter(0, MailStatus.SENT,
                now.minus(Duration.ofMinutes(1)));
        return (int) Math.max(0, Math.min(batch, props.maxPerMinute() - sent));
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
        boolean announcement = MailCategory.of(m.getTemplate()) == MailCategory.ANNOUNCEMENT;
        if (props.enabled() && quota != null && !quota.allow(announcement)) {
            // Gunluk kota: DEAD yapma, kota gunu donene dek beklemede tut (kod postalari o zaman zaten bayatlar
            // ve isStaleCodeMail ile gonderilmeden kapanir; duyurular ertesi gun gider).
            m.setNextAttemptAt(quota.nextReset(Instant.now()));
            metrics.counter("mail.queue.quota_deferred").increment();
            log.warn("Gunluk e-posta kotasi doldu/ayrildi, kayit ertelendi id={} sablon={}", m.getId(), m.getTemplate());
            outbox.save(m);
            return;
        }
        if (announcement && !prepareAnnouncement(m)) {
            outbox.save(m);
            return;
        }
        try {
            deliver(m);
            if (props.enabled() && quota != null) {
                quota.recordSent();
            }
            m.markSent(Instant.now());
            metrics.counter("mail.queue.sent").increment();
        } catch (Exception e) {
            if (MailBounces.isPermanentRecipientFailure(e)) {
                handleBounce(m, e);
            } else {
                recordFailure(m, e);
            }
        }
        outbox.save(m);
    }

    /**
     * Duyuru on kontrolleri. false = bu tur gonderilmeyecek (kayit guncellendi): bastirilmis adres SKIPPED olur;
     * ayni aliciya yakin zamanda duyuru gittiyse ileri tarihe ertelenir; abonelik baglantisi yoksa SKIPPED.
     */
    private boolean prepareAnnouncement(MailOutbox m) {
        if (suppression != null && suppression.isSuppressed(m.getToAddress())) {
            m.markSkipped("bastirma listesinde");
            metrics.counter("mail.queue.suppressed").increment();
            return false;
        }
        if (tokens == null || tokens.url(m.getToAddress(), Lang.of(m.getLang()), Instant.now()) == null) {
            m.markSkipped("abonelikten cikma baglantisi yapilandirilmamis (app.mail.unsubscribe-base-url)");
            log.error("Duyuru gonderilemedi: app.mail.unsubscribe-base-url tanimli degil (id={})", m.getId());
            return false;
        }
        int gap = props.recipientGapSeconds();
        if (gap > 0 && outbox.existsByToAddressAndPriorityGreaterThanAndStatusAndSentAtAfter(m.getToAddress(), 0,
                MailStatus.SENT, Instant.now().minusSeconds(gap))) {
            m.setNextAttemptAt(Instant.now().plusSeconds(gap));
            metrics.counter("mail.queue.deferred").increment();
            return false;
        }
        return true;
    }

    /** Adres kalici olarak yok: yeniden denenmez, adres BOUNCED olarak bastirilir (sonraki duyurular gitmez). */
    private void handleBounce(MailOutbox m, Exception e) {
        if (suppression != null) {
            suppression.suppress(m.getToAddress(), SuppressionReason.BOUNCED);
        }
        m.markSkipped("kalici teslim hatasi (bounce): " + e.getClass().getSimpleName());
        metrics.counter("mail.queue.bounced").increment();
        log.warn("E-posta kalici hata (bounce), adres bastirildi id={} alici={}", m.getId(),
                MailAddresses.mask(m.getToAddress()));
    }

    private static boolean isStaleCodeMail(MailOutbox m) {
        return (m.getTemplate() == MailTemplate.VERIFICATION_CODE || m.getTemplate() == MailTemplate.PASSWORD_RESET_CODE)
                && m.getCreatedAt() != null && m.getCreatedAt().isBefore(Instant.now().minus(CODE_MAIL_MAX_AGE));
    }

    private void deliver(MailOutbox m) throws Exception {
        Map<String, String> vars = json.readValue(m.getVarsJson(), VARS_TYPE);
        Lang lang = Lang.of(m.getLang());
        MailRenderer.Rendered mail = renderer.render(m.getTemplate(), lang, vars);
        MailCategory category = MailCategory.of(m.getTemplate());
        String unsubscribeUrl = null;
        if (category == MailCategory.ANNOUNCEMENT) {
            unsubscribeUrl = tokens.url(m.getToAddress(), lang, Instant.now());
            mail = UnsubscribeFooter.append(mail, unsubscribeUrl, lang);
        }
        if (props.enabled()) {
            if (category == MailCategory.TRANSACTIONAL) {
                transport.send(m.getToAddress(), mail.subject(), mail.text(), mail.html(), null);
            } else {
                transport.send(m.getToAddress(), mail.subject(), mail.text(), mail.html(), null, category,
                        unsubscribeUrl);
            }
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
