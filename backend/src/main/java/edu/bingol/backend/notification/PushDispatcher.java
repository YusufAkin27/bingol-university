package edu.bingol.backend.notification;

import edu.bingol.backend.notification.fcm.FcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import edu.bingol.backend.notification.fcm.SendResult;
import edu.bingol.backend.notification.outbox.PushOutboxService;
import jakarta.annotation.PreDestroy;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.concurrent.Executor;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * Push'u istek thread'ini bloklamadan arka planda gonderir: 500'luk parcalar, gecici hatalarda ustel geri cekilmeyle
 * yeniden deneme, gecersiz token temizligi. FCM kapaliyken hicbir sey yapmaz (uygulama ici kutu ayri yazilir).
 */
@Component
public class PushDispatcher {

    private static final Logger log = LoggerFactory.getLogger(PushDispatcher.class);
    static final int CHUNK = 500;
    static final int MAX_RETRIES = 3;
    private static final long BASE_DELAY_MS = 5_000;

    /** Yeniden deneme zamanlayicisi: (is, gecikme ms). */
    interface Scheduler {
        void schedule(Runnable task, long delayMs);
    }

    @org.springframework.beans.factory.annotation.Value("${PUBLIC_WEB_URL:}")
    private String publicWebUrl = "";

    private final FcmSender fcm;
    private final DeviceRepository devices;
    private final Executor executor;
    private final Scheduler scheduler;
    private final ThreadPoolExecutor ownPool;
    private final ScheduledThreadPoolExecutor ownTimer;
    /** Kalici kuyruk (null ise eski bellek yolu). */
    private final PushOutboxService outbox;

    private final AtomicLong delivered = new AtomicLong();
    private final AtomicLong failures = new AtomicLong();
    private final AtomicLong retries = new AtomicLong();
    private final AtomicLong dropped = new AtomicLong();
    private volatile Instant lastFailureAt;

    public PushDispatcher(FcmSender fcm, DeviceRepository devices) {
        this(fcm, devices, (PushOutboxService) null);
    }

    @Autowired
    public PushDispatcher(FcmSender fcm, DeviceRepository devices, ObjectProvider<PushOutboxService> outbox) {
        this(fcm, devices, outbox.getIfAvailable());
    }

    PushDispatcher(FcmSender fcm, DeviceRepository devices, PushOutboxService outbox) {
        this.fcm = fcm;
        this.devices = devices;
        this.outbox = outbox;
        // core=max: sinirli kuyrukta max thread hic devreye girmez, bu yuzden esit tutulur.
        this.ownPool = new ThreadPoolExecutor(4, 4, 30, TimeUnit.SECONDS, new LinkedBlockingQueue<>(2000),
                r -> daemon(r, "push-send"));
        this.ownPool.allowCoreThreadTimeOut(true);
        this.ownTimer = new ScheduledThreadPoolExecutor(1, r -> daemon(r, "push-retry"));
        this.executor = ownPool;
        this.scheduler = (task, ms) -> ownTimer.schedule(task, ms, TimeUnit.MILLISECONDS);
    }

    /** Testler icin: es zamanli calistirma ve elle tetiklenen zamanlayici. */
    PushDispatcher(FcmSender fcm, DeviceRepository devices, Executor executor, Scheduler scheduler) {
        this.fcm = fcm;
        this.devices = devices;
        this.executor = executor;
        this.scheduler = scheduler;
        this.outbox = null;
        this.ownPool = null;
        this.ownTimer = null;
    }

    private static Thread daemon(Runnable r, String name) {
        Thread t = new Thread(r, name);
        t.setDaemon(true);
        return t;
    }

    /** Gonderim kabul ediliyor mu: FCM etkin ya da kalici kuyruk "FCM yokken beklet" modunda. */
    public boolean enabled() {
        return fcm.enabled() || (outbox != null && outbox.holdWhenDisabled());
    }

    /** Yonetici kontrolu: yapilandirma durumu; dryRun=true ise FCM validateOnly istegi (cihaza gitmez). */
    public edu.bingol.backend.notification.fcm.FcmCheck fcmCheck(boolean dryRun) {
        return fcm.check(dryRun);
    }

    /** FCM kimligi gercekten var mi (saglik gostergesi icin). */
    public boolean fcmEnabled() {
        return fcm.enabled();
    }

    /** Kuyruga atar ve hemen doner; hata cagirana sizmaz. */
    public void dispatch(Collection<String> tokens, PushMessage original) {
        final PushMessage message = RichPushPayload.normalizeMedia(original, publicWebUrl);
        if (tokens == null || tokens.isEmpty()) {
            return;
        }
        if (!RichPushPayload.isRich(message)) {
            try {
                var all = List.copyOf(tokens);
                var nativeTokens = new java.util.HashSet<String>();
                var byLocale = new java.util.HashMap<String, java.util.List<String>>();
                for (int i = 0; i < all.size(); i += CHUNK) {
                    var rows = devices.findByFcmTokenIn(all.subList(i, Math.min(i + CHUNK, all.size())));
                    if (rows != null) for (Device device : rows) {
                        if (!device.isRichNotifications() || !"ANDROID".equals(device.getPlatform())) continue;
                        nativeTokens.add(device.getFcmToken());
                        String locale = device.getLocale() == null ? "tr" : device.getLocale();
                        byLocale.computeIfAbsent(device.getUserId() + ":" + locale, k -> new ArrayList<>()).add(device.getFcmToken());
                    }
                }
                for (var entry : byLocale.entrySet()) {
                    String[] recipient = entry.getKey().split(":", 2);
                    var rich = RichPushPayload.enrich(message, publicWebUrl, recipient[1], Long.valueOf(recipient[0]));
                    // Oversized enrichment falls back once, without recursive re-enrichment.
                    if (RichPushPayload.isRich(rich)) dispatch(entry.getValue(), rich);
                    else nativeTokens.removeAll(entry.getValue());
                }
                tokens = all.stream().filter(t -> !nativeTokens.contains(t)).toList();
                if (tokens.isEmpty()) return;
            } catch (RuntimeException e) {
                log.warn("Native notification capability check failed: {}", e.getClass().getSimpleName());
            }
        }
        if (outbox != null) {
            if (!outbox.accepting()) {
                outbox.skipped(tokens.size()); // FCM yok, tutma kapali: birikmesin
                return;
            }
            try {
                outbox.enqueueTokens(tokens, message, null);
                return;
            } catch (RuntimeException e) {
                recordFailure("kalici kuyruga yazilamadi: " + e.getClass().getSimpleName());
                if (!fcm.enabled()) {
                    return;
                }
                // kuyruk yazilamadiysa eski bellek yoluna dus
            }
        }
        if (!fcm.enabled()) {
            return;
        }
        List<String> all = List.copyOf(tokens);
        try {
            executor.execute(() -> sendChunks(all, message, 0));
        } catch (RejectedExecutionException e) {
            recordDropped(all.size());
        }
    }

    /** Genel yayin icin aralik tabanli kalici kuyruk yazimi kullanilabilir mi (kuyruk + PostgreSQL). */    public boolean rangeBroadcastSupported() {
        return outbox != null && outbox.rangeEnqueueSupported();
    }

    /**
     * Genel yayin: kullanici kimligi araligindaki (after, hi] alicilarin cihazlarini TEK ifadeyle kuyruga yazar
     * ({@link #rangeBroadcastSupported()} true iken). Hata cagirana sizmaz.
     */
    public int dispatchRange(PushMessage original, String prefColumn, String lang, long after, long hi) {
        if (!rangeBroadcastSupported()) {
            return 0;
        }
        final PushMessage message = RichPushPayload.normalizeMedia(original, publicWebUrl);
        if (!outbox.accepting()) {
            return 0; // FCM yok, tutma kapali: birikmesin
        }
        try {
            // Android zengin cizici (veri-only, yuksek oncelik: uygulama kapaliyken de yerel kart) ve digerleri (standart
            // FCM bildirimi / APNs alert) icin iki ayri yuk; cihaz kaydindaki `richNotifications` ayirir.
            PushMessage rich = RichPushPayload.enrichBroadcast(message, publicWebUrl, lang);
            if (RichPushPayload.isRich(rich)) {
                return outbox.enqueueBroadcastRange(message, prefColumn, lang, after, hi, BroadcastWriter.DEVICES_STANDARD)
                        + outbox.enqueueBroadcastRange(rich, prefColumn, lang, after, hi, BroadcastWriter.DEVICES_RICH);
            }
            return outbox.enqueueBroadcastRange(message, prefColumn, lang, after, hi);
        } catch (RuntimeException e) {
            recordFailure("kalici kuyruga toplu yazilamadi: " + e.getClass().getSimpleName());
            return 0;
        }
    }

    private void sendChunks(List<String> all, PushMessage message, int attempt) {
        for (int i = 0; i < all.size(); i += CHUNK) {
            sendChunk(all.subList(i, Math.min(i + CHUNK, all.size())), message, attempt);
        }
    }

    private void sendChunk(List<String> chunk, PushMessage message, int attempt) {
        try {
            SendResult r = fcm.deliver(chunk, message);
            List<String> invalid = r.invalid() == null ? List.of() : r.invalid();
            List<String> retryable = r.retryable() == null ? List.of() : r.retryable();
            List<String> permanent = r.permanent() == null ? List.of() : r.permanent();
            if (!invalid.isEmpty()) {
                devices.deleteByFcmTokenIn(invalid);
            }
            if (!permanent.isEmpty()) {
                recordFailure(permanent.size() + " cihaz icin kalici FCM hatasi (" + String.join(",",
                        permanent.stream().map(t -> r.codes() == null ? "?" : r.codes().getOrDefault(t, "?"))
                                .distinct().toList()) + ")");
            }
            delivered.addAndGet(Math.max(0, chunk.size() - invalid.size() - retryable.size() - permanent.size()));
            if (!retryable.isEmpty()) {
                scheduleRetry(new ArrayList<>(retryable), message, attempt);
            }
        } catch (RuntimeException e) {
            recordFailure(e.getClass().getSimpleName());
        }
    }

    private void scheduleRetry(List<String> tokens, PushMessage message, int attempt) {
        if (attempt >= MAX_RETRIES) {
            recordFailure(tokens.size() + " cihaz icin gecici hata, vazgecildi");
            return;
        }
        retries.incrementAndGet();
        scheduler.schedule(() -> {
            try {
                executor.execute(() -> sendChunks(tokens, message, attempt + 1));
            } catch (RejectedExecutionException e) {
                recordDropped(tokens.size());
            }
        }, backoffMillis(attempt));
    }

    /** 5 sn, 20 sn, 80 sn... (x4). */
    static long backoffMillis(int attempt) {
        return BASE_DELAY_MS * (1L << (2 * attempt));
    }

    private void recordFailure(String reason) {
        failures.incrementAndGet();
        lastFailureAt = Instant.now();
        log.warn("Push gonderimi basarisiz: {}", reason);
    }

    /** Kuyruk dolunca dusen push: WARN log + hata sayaci + ayri dusen sayaci. */
    private void recordDropped(int tokenCount) {
        dropped.addAndGet(tokenCount);
        recordFailure("kuyruk dolu, " + tokenCount + " cihaz icin push dusuruldu");
    }

    public long droppedCount() {
        return dropped.get();
    }

    public long deliveredCount() {
        return delivered.get();
    }

    public long failureCount() {
        return failures.get();
    }

    public long retryCount() {
        return retries.get();
    }

    public Instant lastFailureAt() {
        return lastFailureAt;
    }

    @PreDestroy
    void shutdown() {
        if (ownPool != null) {
            ownPool.shutdown();
            try {
                // Kuyruktaki gonderimlere kisa sure tani; bitmezse kalanlar atilir.
                if (!ownPool.awaitTermination(5, TimeUnit.SECONDS)) {
                    ownPool.shutdownNow();
                }
            } catch (InterruptedException e) {
                ownPool.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }
        if (ownTimer != null) {
            ownTimer.shutdownNow();
        }
    }
}
