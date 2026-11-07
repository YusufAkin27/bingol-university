package edu.bingol.backend.forum.notify;

import edu.bingol.backend.common.AfterCommit;
import edu.bingol.backend.forum.notify.spi.ForumEventPublisher;
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
import org.springframework.stereotype.Service;

/**
 * {@link ForumEventPublisher} uygulamasi (E). Olaylari islem COMMIT olduktan sonra (islem yoksa hemen) ayri, sinirli bir
 * yurutucude {@link ForumNotifier}'a verir: bildirim hatasi ya da yavasligi ana islemi ASLA bozmaz ve bir kullanici
 * eyleminin baglantisini tutmaz (post.notify.NotifyDispatcher ile ayni gerekce). Kuyruk dolarsa bildirim atilir
 * (en iyi cabalik; uygulama ici kutu ve sayaclar etkilenmez).
 *
 * <p>{@code app.forum.notify-async=false}: ayni is parcaciginda (birim/entegrasyon testleri; commit sonrasi baglama
 * dikkat: yalniz islem disi cagrilarda guvenlidir).
 */
@Service
public class ForumEventPublisherImpl implements ForumEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(ForumEventPublisherImpl.class);

    private final ForumNotifier notifier;
    private final ThreadPoolExecutor pool;
    private final AtomicLong dropped = new AtomicLong();

    public ForumEventPublisherImpl(ForumNotifier notifier,
                                   @Value("${app.forum.notify-async:true}") boolean async,
                                   @Value("${app.forum.notify-threads:2}") int threads,
                                   @Value("${app.forum.notify-queue:2000}") int queue) {
        this.notifier = notifier;
        if (async) {
            AtomicInteger n = new AtomicInteger();
            ThreadFactory tf = r -> {
                Thread t = new Thread(r, "forum-notify-" + n.incrementAndGet());
                t.setDaemon(true);
                return t;
            };
            this.pool = new ThreadPoolExecutor(Math.max(1, threads), Math.max(1, threads), 30, TimeUnit.SECONDS,
                    new ArrayBlockingQueue<>(Math.max(1, queue)), tf, new ThreadPoolExecutor.AbortPolicy());
        } else {
            this.pool = null;
        }
    }

    @Override
    public void topicLiked(Long topicId, Long actorId) {
        if (topicId == null || actorId == null) {
            return;
        }
        later("topicLiked", () -> notifier.topicLiked(topicId, actorId));
    }

    @Override
    public void commentCreated(Long commentId, Long actorId) {
        if (commentId == null || actorId == null) {
            return;
        }
        later("commentCreated", () -> notifier.commentCreated(commentId, actorId));
    }

    @Override
    public void commentLiked(Long commentId, Long actorId) {
        if (commentId == null || actorId == null) {
            return;
        }
        later("commentLiked", () -> notifier.commentLiked(commentId, actorId));
    }

    @Override
    public void moderationAction(TargetType targetType, Long targetId, String action, String reason) {
        if (targetType == null || targetId == null) {
            return;
        }
        later("moderationAction", () -> notifier.moderated(targetType == TargetType.COMMENT, targetId, action, reason));
    }

    private void later(String what, Runnable task) {
        try {
            AfterCommit.run(() -> dispatch(what, task));
        } catch (RuntimeException e) {
            log.warn("Forum bildirimi siraya alinamadi ({}): {}", what, e.toString());
        }
    }

    private void dispatch(String what, Runnable task) {
        Runnable safe = () -> {
            try {
                task.run();
            } catch (RuntimeException e) {
                log.warn("Forum bildirimi gonderilemedi ({}): {}", what, e.toString());
            }
        };
        if (pool == null) {
            safe.run();
            return;
        }
        try {
            pool.execute(safe);
        } catch (RejectedExecutionException e) {
            if (dropped.incrementAndGet() % 100 == 1) {
                log.warn("Forum bildirim kuyrugu dolu, bildirim atildi (toplam {})", dropped.get());
            }
        }
    }

    @PreDestroy
    void shutdown() {
        if (pool != null) {
            pool.shutdown();
        }
    }
}
