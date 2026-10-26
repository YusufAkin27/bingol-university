package edu.bingol.backend.notification;

import edu.bingol.backend.notification.fcm.FcmSender;
import edu.bingol.backend.notification.fcm.PushMessage;
import edu.bingol.backend.notification.fcm.SendResult;
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

    private final FcmSender fcm;
    private final DeviceRepository devices;
    private final Executor executor;
    private final Scheduler scheduler;
    private final ThreadPoolExecutor ownPool;
    private final ScheduledThreadPoolExecutor ownTimer;

    private final AtomicLong delivered = new AtomicLong();
    private final AtomicLong failures = new AtomicLong();
    private final AtomicLong retries = new AtomicLong();
    private final AtomicLong dropped = new AtomicLong();
    private volatile Instant lastFailureAt;

    @Autowired
    public PushDispatcher(FcmSender fcm, DeviceRepository devices) {
        this.fcm = fcm;
        this.devices = devices;
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
        this.ownPool = null;
        this.ownTimer = null;
    }

    private static Thread daemon(Runnable r, String name) {
        Thread t = new Thread(r, name);
        t.setDaemon(true);
        return t;
    }

    public boolean enabled() {
        return fcm.enabled();
    }

    /** Kuyruga atar ve hemen doner; hata cagirana sizmaz. */
    public void dispatch(Collection<String> tokens, PushMessage message) {
        if (tokens == null || tokens.isEmpty() || !fcm.enabled()) {
            return;
        }
        List<String> all = List.copyOf(tokens);
        try {
            executor.execute(() -> sendChunks(all, message, 0));
        } catch (RejectedExecutionException e) {
            recordDropped(all.size());
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
            if (!invalid.isEmpty()) {
                devices.deleteByFcmTokenIn(invalid);
            }
            delivered.addAndGet(Math.max(0, chunk.size() - invalid.size() - retryable.size()));
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
