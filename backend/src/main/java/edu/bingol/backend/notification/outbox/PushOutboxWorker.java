package edu.bingol.backend.notification.outbox;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.notification.Device;
import edu.bingol.backend.notification.DeviceRepository;
import edu.bingol.backend.notification.fcm.FcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import edu.bingol.backend.notification.fcm.SendResult;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.annotation.PreDestroy;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionalEventListener;
import tools.jackson.databind.json.JsonMapper;

/**
 * Push kuyrugunu isler (mail/MailQueueWorker kalibi). Birden fazla sunucuda guvenlidir (claimDue: SKIP LOCKED + kira).
 * Ayni yuke sahip kayitlar 500'luk gruplar halinde tek FCM cagrisiyla gonderilir. Gecici hata: ustel geri cekilme,
 * N denemeden sonra DEAD; gecersiz token (UNREGISTERED): cihaz kaydi silinir + DEAD. Servis sozlesmesi: istisna sizdirmaz.
 */
@Component
@ConditionalOnProperty(name = "app.push.outbox.enabled", havingValue = "true", matchIfMissing = true)
public class PushOutboxWorker {

    private static final Logger log = LoggerFactory.getLogger(PushOutboxWorker.class);
    /** Bir turda alinan kaydin baska sunucularca tekrar alinmamasi icin kira suresi. */
    static final Duration LEASE = Duration.ofMinutes(5);
    static final Duration SENT_RETENTION = Duration.ofDays(7);
    static final Duration DEAD_RETENTION = Duration.ofDays(30);

    private final PushOutboxRepository repo;
    private final DeviceRepository devices;
    private final FcmSender fcm;
    private final JsonMapper json;
    private final MeterRegistry metrics;
    private final SchedulerLock lock;
    private final boolean holdWhenDisabled;
    private final int batchSize;
    private final int maxAttempts;
    private final Duration maxAge;
    private final ExecutorService nudgeExecutor = Executors.newSingleThreadExecutor(r -> {
        Thread t = new Thread(r, "push-outbox-nudge");
        t.setDaemon(true);
        return t;
    });

    public PushOutboxWorker(PushOutboxRepository repo, DeviceRepository devices, FcmSender fcm, JsonMapper json,
                            MeterRegistry metrics, SchedulerLock lock,
                            @Value("${app.push.outbox.hold-when-disabled:false}") boolean holdWhenDisabled,
                            @Value("${app.push.outbox.batch-size:500}") int batchSize,
                            @Value("${app.push.outbox.max-attempts:6}") int maxAttempts,
                            @Value("${app.push.outbox.max-age-hours:24}") int maxAgeHours) {
        this.repo = repo;
        this.devices = devices;
        this.fcm = fcm;
        this.json = json;
        this.metrics = metrics;
        this.lock = lock;
        this.holdWhenDisabled = holdWhenDisabled;
        this.batchSize = Math.max(1, batchSize);
        this.maxAttempts = Math.max(1, maxAttempts);
        this.maxAge = Duration.ofHours(Math.max(1, maxAgeHours));
    }

    /** Acilista, onceki surecten kalan SENDING (kirasi dolmus) kayitlari PENDING'e geri alir. */
    @EventListener(ApplicationReadyEvent.class)
    public void recoverOnStartup() {
        try {
            int n = repo.recoverStale(Instant.now());
            if (n > 0) {
                log.info("{} yarim kalan push kaydi kuyruga geri alindi", n);
            }
        } catch (RuntimeException e) {
            log.warn("Push kuyrugu kurtarma basarisiz: {}", e.toString());
        }
    }

    /** Yeni push yazilinca (transaction commit'inden sonra) beklemeden bir tur calistirir. */
    @TransactionalEventListener(fallbackExecution = true)
    void onQueued(PushQueued event) {
        try {
            nudgeExecutor.execute(this::processDue);
        } catch (RuntimeException e) {
            log.debug("Push isleyici tetiklenemedi, zamanlayici alacak: {}", e.toString());
        }
    }

    @Scheduled(fixedDelayString = "${app.push.outbox.poll-ms:5000}")
    public void poll() {
        processDue();
    }

    /** SENT 7 gun, DEAD 30 gun sonra silinir; 30 gunden eski her kayit (takilmis dahil) gider. */
    @Scheduled(cron = "${app.push.outbox.cleanup-cron:0 20 3 * * *}", zone = "Europe/Istanbul")
    public void purgeOld() {
        lock.tryRun("push-outbox-cleanup", Duration.ofMinutes(10), this::purgeNow);
    }

    void purgeNow() {
        try {
            Instant now = Instant.now();
            int sent = repo.deleteByStatusBefore(PushOutboxStatus.SENT, now.minus(SENT_RETENTION));
            int dead = repo.deleteByStatusBefore(PushOutboxStatus.DEAD, now.minus(DEAD_RETENTION));
            int stuck = repo.deleteByStatusInBefore(
                    List.of(PushOutboxStatus.PENDING, PushOutboxStatus.FAILED, PushOutboxStatus.SENDING),
                    now.minus(DEAD_RETENTION));
            if (sent + dead + stuck > 0) {
                log.info("Push kuyrugu temizligi: {} gonderilmis, {} olu, {} takilmis kayit silindi", sent, dead, stuck);
            }
        } catch (RuntimeException e) {
            log.warn("Push kuyruk temizligi basarisiz: {}", e.toString());
        }
    }

    /** Zamani gelen kayitlari bir parti halinde isler; FCM kapaliysa (ve tutma acikken) kayitlara dokunmaz. */
    public void processDue() {
        try {
            if (!fcm.enabled()) {
                return; // kayitlar PENDING'de bekler (hold) ya da hic yazilmaz
            }
            Instant now = Instant.now();
            List<Long> ids = repo.claimDue(now, now.plus(LEASE), batchSize);
            if (ids.isEmpty()) {
                return;
            }
            process(repo.findAllById(ids), now);
        } catch (Exception e) {
            log.error("Push kuyrugu islenemedi: {}", e.toString());
        }
    }

    /** Kiralanan kayitlari gonderir ve son durumlarini yazar. */
    void process(List<PushOutbox> rows, Instant now) {
        Set<Long> deviceIds = rows.stream().map(PushOutbox::getDeviceId).filter(java.util.Objects::nonNull)
                .collect(Collectors.toSet());
        Map<Long, Device> byId = new HashMap<>();
        if (!deviceIds.isEmpty()) {
            devices.findAllById(deviceIds).forEach(d -> byId.put(d.getId(), d));
        }
        // Ayni yuke sahip kayitlar tek multicast'te
        Map<String, List<PushOutbox>> groups = new LinkedHashMap<>();
        for (PushOutbox r : rows) {
            if (r.getStatus() != PushOutboxStatus.SENDING) {
                continue; // baska surec/yonetici durumunu degistirmis
            }
            if (r.age(now).compareTo(maxAge) > 0) {
                dead(r, "suresi doldu, gonderilmedi");
            } else if (r.getDeviceId() == null || !byId.containsKey(r.getDeviceId())) {
                dead(r, "cihaz kaydi yok (silinmis)");
            } else {
                groups.computeIfAbsent(r.getPayloadJson(), k -> new ArrayList<>()).add(r);
            }
        }
        for (Map.Entry<String, List<PushOutbox>> g : groups.entrySet()) {
            sendGroup(g.getKey(), g.getValue(), byId, now);
        }
        repo.saveAll(rows);
    }

    private void sendGroup(String payload, List<PushOutbox> group, Map<Long, Device> byId, Instant now) {
        PushMessage message;
        try {
            message = json.readValue(payload, PushMessage.class);
        } catch (RuntimeException e) {
            group.forEach(r -> dead(r, "yuk okunamadi"));
            return;
        }
        for (int i = 0; i < group.size(); i += 500) {
            List<PushOutbox> chunk = group.subList(i, Math.min(i + 500, group.size()));
            Map<String, List<PushOutbox>> byToken = new LinkedHashMap<>();
            for (PushOutbox r : chunk) {
                byToken.computeIfAbsent(byId.get(r.getDeviceId()).getFcmToken(), k -> new ArrayList<>()).add(r);
            }
            try {
                SendResult res = fcm.deliver(byToken.keySet(), message);
                Set<String> invalid = new HashSet<>(res.invalid() == null ? List.of() : res.invalid());
                Set<String> retry = new HashSet<>(res.retryable() == null ? List.of() : res.retryable());
                if (!invalid.isEmpty()) {
                    devices.deleteByFcmTokenIn(invalid);
                }
                byToken.forEach((token, list) -> list.forEach(r -> {
                    if (invalid.contains(token)) {
                        dead(r, "UNREGISTERED: cihaz kaydi silindi");
                    } else if (retry.contains(token)) {
                        failed(r, "gecici FCM hatasi", now);
                    } else {
                        r.markSent(now);
                        metrics.counter("push.outbox.sent").increment();
                    }
                }));
            } catch (RuntimeException e) {
                // Mesaj/token icermez: yalniz hata turu
                chunk.forEach(r -> failed(r, e.getClass().getSimpleName(), now));
            }
        }
    }

    private void failed(PushOutbox r, String error, Instant now) {
        r.markFailed(error, now, maxAttempts);
        metrics.counter("push.outbox.failed").increment();
        if (r.getStatus() == PushOutboxStatus.DEAD) {
            metrics.counter("push.outbox.dead").increment();
            log.warn("Push {} deneme sonunda gonderilemedi (DEAD) id={} kullanici={}", r.getAttempts(), r.getId(), r.getUserId());
        }
    }

    private void dead(PushOutbox r, String reason) {
        r.markDead(reason);
        metrics.counter("push.outbox.dead").increment();
    }

    public boolean holdWhenDisabled() {
        return holdWhenDisabled;
    }

    @PreDestroy
    void shutdown() {
        nudgeExecutor.shutdown();
    }
}
