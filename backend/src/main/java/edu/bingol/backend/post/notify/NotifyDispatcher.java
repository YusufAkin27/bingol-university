package edu.bingol.backend.post.notify;

import jakarta.annotation.PreDestroy;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Takip/istek bildirimlerini istek ipliğinin dışında çalıştırır (A06#10). {@code afterCommit} içinde
 * {@code REQUIRES_NEW} ile yeni işlem açmak, dış işlemin bağlantısı serbest kalmadan havuzdan İKİNCİ bağlantı tutar
 * (havuz 30; eşzamanlı takip commit'leri birbirini bekler). Bildirimi küçük, SINIRLI bir yürütücüye bırakmak bağlantıyı
 * erken serbest bırakır. En iyi çaba: kuyruk doluysa bildirim atılır (kullanıcı eylemi etkilenmez).
 *
 * <p>{@code app.post.notify-async} varsayılan KAPALI: bugünkü davranış (aynı iş parçacığında, eşzamanlı). Açmak için
 * ortamda {@code APP_POST_NOTIFY_ASYNC=true} (iş parçacığı: {@code app.post.notify-threads}, kuyruk:
 * {@code app.post.notify-queue}).
 */
@Component
public class NotifyDispatcher {

    private static final Logger log = LoggerFactory.getLogger(NotifyDispatcher.class);

    private final ThreadPoolExecutor pool;
    private final AtomicLong dropped = new AtomicLong();

    public NotifyDispatcher(@Value("${app.post.notify-async:false}") boolean async,
                            @Value("${app.post.notify-threads:2}") int threads,
                            @Value("${app.post.notify-queue:2000}") int queue) {
        if (async) {
            AtomicInteger n = new AtomicInteger();
            ThreadFactory tf = r -> {
                Thread t = new Thread(r, "post-notify-" + n.incrementAndGet());
                t.setDaemon(true);
                return t;
            };
            this.pool = new ThreadPoolExecutor(Math.max(1, threads), Math.max(1, threads), 30, TimeUnit.SECONDS,
                    new ArrayBlockingQueue<>(Math.max(1, queue)), tf, new ThreadPoolExecutor.AbortPolicy());
        } else {
            this.pool = null;
        }
    }

    /** Görevi çalıştırır: async kapalıysa hemen bu iş parçacığında; açıksa sınırlı yürütücüde (hata yutulur). */
    public void run(Runnable task) {
        if (pool == null) {
            task.run();
            return;
        }
        try {
            pool.execute(() -> {
                try {
                    task.run();
                } catch (RuntimeException e) {
                    log.warn("Gonderi bildirimi gonderilemedi: {}", e.toString());
                }
            });
        } catch (RejectedExecutionException e) {
            if (dropped.incrementAndGet() % 100 == 1) {
                log.warn("Gonderi bildirim kuyrugu dolu, bildirim atildi (toplam {})", dropped.get());
            }
        }
    }

    long dropped() {
        return dropped.get();
    }

    @PreDestroy
    void shutdown() {
        if (pool != null) {
            pool.shutdown();
        }
    }
}
