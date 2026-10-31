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
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
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
    /** Farkli yuklu gruplari es zamanli gondermek icin (FCM cagrisi G/C bagimlidir). */
    private final ExecutorService sendPool = Executors.newFixedThreadPool(4, r -> {
        Thread t = new Thread(r, "push-outbox-send");
        t.setDaemon(true);
        return t;
    });
    /** Takili FCM cagrisi tum tur(lar)i sonsuza dek bloklamasin: grup gonderimlerinin toplam bekleme siniri (T-074). */
    private volatile long groupSendTimeoutMs = 30_000;
    /** Bir tur zaten siradaysa ikincisi yigilmaz (poll + nudge ayni yurutucuyu paylasir). */
    private final AtomicBoolean roundQueued = new AtomicBoolean(false);
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
        submitRound();
    }

    /**
     * Zamanlayici yalniz turu SIRAYA koyar; FCM beklemesi {@code sched-*} havuzunu degil kendi tek is parcacikli
     * yurutucusunu tutar (T-074 / A2-10: FCM yanit vermezse posta, presence, bakim donguleri etkilenmesin).
     */
    @Scheduled(fixedDelayString = "${app.push.outbox.poll-ms:5000}")
    public void poll() {
        submitRound();
    }

    private void submitRound() {
        if (!roundQueued.compareAndSet(false, true)) {
            return; // zaten sirada/kosuyor: bir sonraki kayitlar o turda ya da sonraki zamanlayici vurusunda alinir
        }
        try {
            nudgeExecutor.execute(() -> {
                roundQueued.set(false); // tur BASLARKEN acilir: calisirken gelen yeni kayit icin yeni tur siraya girebilir
                processDue();
            });
        } catch (RuntimeException e) {
            roundQueued.set(false);
            log.debug("Push isleyici tetiklenemedi, zamanlayici alacak: {}", e.toString());
        }
    }

    /** Test: grup gonderimi toplam bekleme siniri (ms). */
    void setGroupSendTimeoutMs(long ms) {
        this.groupSendTimeoutMs = Math.max(1, ms);
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
            repo.deleteByStatusBefore(PushOutboxStatus.CANCELLED, now.minus(DEAD_RETENTION));
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
                dead(r, "suresi doldu, gonderilmedi", "EXPIRED");
            } else if (r.getDeviceId() == null || !byId.containsKey(r.getDeviceId())) {
                dead(r, "cihaz kaydi yok (silinmis)", "DEVICE_MISSING");
            } else {
                groups.computeIfAbsent(r.getPayloadJson(), k -> new ArrayList<>()).add(r);
            }
        }
        if (groups.size() <= 1) {
            groups.forEach((payload, list) -> sendGroup(payload, list, byId, now, null));
        } else {
            // Alici basina farkli yuk (sohbet mesajlari): her grup ayri FCM cagrisi. Ardisik gonderim 500 uyeli bir
            // grupta dakikalarca surerdi; sinirli esdegerlikle gonderilir (gruplar ayri satirlari degistirir).
            List<java.util.concurrent.Callable<Void>> tasks = new ArrayList<>();
            List<AtomicBoolean> abandoned = new ArrayList<>();
            groups.forEach((payload, list) -> {
                AtomicBoolean flag = new AtomicBoolean();
                abandoned.add(flag);
                tasks.add(() -> {
                    sendGroup(payload, list, byId, now, flag);
                    return null;
                });
            });
            try {
                List<Future<Void>> done = sendPool.invokeAll(tasks, groupSendTimeoutMs, TimeUnit.MILLISECONDS);
                // Sinira takilip iptal edilen gruplar: SENDING'de kalmasin, ustel geri cekilmeyle yeniden denensin
                int i = 0;
                for (List<PushOutbox> list : groups.values()) {
                    AtomicBoolean flag = abandoned.get(i);
                    if (done.get(i++).isCancelled()) {
                        flag.set(true); // gec donen FCM cagrisi satirlari artik degistirmesin (yeniden denenecek)
                        list.forEach(r -> {
                            if (r.getStatus() == PushOutboxStatus.SENDING) {
                                failed(r, "FCM zaman asimi", now, "SEND_TIMEOUT");
                            }
                        });
                    }
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
        repo.saveAll(rows);
    }

    private void sendGroup(String payload, List<PushOutbox> group, Map<Long, Device> byId, Instant now,
                           AtomicBoolean abandoned) {
        PushMessage message;
        try {
            message = json.readValue(payload, PushMessage.class);
        } catch (RuntimeException e) {
            group.forEach(r -> dead(r, "yuk okunamadi", "PAYLOAD_UNREADABLE"));
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
                if (abandoned != null && abandoned.get()) {
                    return; // zaman asimiyla vazgecildi: satirlar FAILED/yeniden deneme olarak yazildi
                }
                Set<String> invalid = new HashSet<>(res.invalid() == null ? List.of() : res.invalid());
                Set<String> retry = new HashSet<>(res.retryable() == null ? List.of() : res.retryable());
                Set<String> permanent = new HashSet<>(res.permanent() == null ? List.of() : res.permanent());
                Map<String, String> codes = res.codes() == null ? Map.of() : res.codes();
                if (!invalid.isEmpty()) {
                    devices.deleteByFcmTokenIn(invalid);
                }
                byToken.forEach((token, list) -> list.forEach(r -> {
                    if (invalid.contains(token)) {
                        dead(r, "UNREGISTERED: cihaz kaydi silindi", codes.getOrDefault(token, "UNREGISTERED"));
                    } else if (permanent.contains(token)) {
                        // THIRD_PARTY_AUTH_ERROR (APNs anahtari), INVALID_ARGUMENT vb.: gonderilmedi, "SENT" sayilmaz
                        dead(r, "kalici FCM hatasi", codes.getOrDefault(token, "PERMANENT"));
                    } else if (retry.contains(token)) {
                        failed(r, "gecici FCM hatasi", now, codes.getOrDefault(token, "UNAVAILABLE"));
                    } else {
                        r.markSent(now);
                        r.setErrorCode(null);
                        metrics.counter("push.outbox.sent").increment();
                    }
                }));
            } catch (RuntimeException e) {
                // Mesaj/token icermez: yalniz hata turu
                chunk.forEach(r -> failed(r, e.getClass().getSimpleName(), now, "SEND_ERROR"));
            }
        }
    }

    /** Surec basindan beri hata kodu sayaclari (saglik gostergesi / teshis; kalici degil). */
    private final java.util.concurrent.ConcurrentHashMap<String, java.util.concurrent.atomic.LongAdder> errorCodes =
            new java.util.concurrent.ConcurrentHashMap<>();

    private void countError(String code) {
        if (code != null) {
            errorCodes.computeIfAbsent(code, k -> new java.util.concurrent.atomic.LongAdder()).increment();
        }
    }

    /** Hata kodu -> adet (surec basindan beri; en cok 50 kod). */
    public Map<String, Long> errorCodeCounts() {
        Map<String, Long> out = new java.util.TreeMap<>();
        errorCodes.forEach((k, v) -> out.put(k, v.sum()));
        return out;
    }

    private void failed(PushOutbox r, String error, Instant now, String errorCode) {
        countError(errorCode);
        r.markFailed(error, now, maxAttempts);
        r.setErrorCode(errorCode);
        metrics.counter("push.outbox.failed").increment();
        if (r.getStatus() == PushOutboxStatus.DEAD) {
            metrics.counter("push.outbox.dead").increment();
            log.warn("Push {} deneme sonunda gonderilemedi (DEAD) id={} kullanici={}", r.getAttempts(), r.getId(), r.getUserId());
        }
    }

    private void dead(PushOutbox r, String reason, String errorCode) {
        countError(errorCode);
        r.markDead(reason);
        r.setErrorCode(errorCode);
        metrics.counter("push.outbox.dead").increment();
    }

    public boolean holdWhenDisabled() {
        return holdWhenDisabled;
    }

    @PreDestroy
    void shutdown() {
        nudgeExecutor.shutdown();
        sendPool.shutdown();
    }
}
