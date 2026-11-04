package edu.bingol.backend.post.comment;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Gece onarimi: yorum/yanit/begeni sayaclarinin gercek satirlarla farkini kapatir (eszamanli yazimdan kalan kayma). */
@Component
public class CommentCounterRepairJob {

    private static final Logger log = LoggerFactory.getLogger(CommentCounterRepairJob.class);

    private final CommentCounters counters;
    private final SchedulerLock lock;

    public CommentCounterRepairJob(CommentCounters counters, SchedulerLock lock) {
        this.counters = counters;
        this.lock = lock;
    }

    @Scheduled(cron = "${app.post.comment-repair-cron:0 40 3 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        try {
            lock.tryRun("post-comment-counter-repair", Duration.ofMinutes(30), this::repair);
        } catch (RuntimeException e) {
            log.warn("Yorum sayac onarimi basarisiz: {}", e.toString());
        }
    }

    public void repair() {
        int n = counters.repairAll();
        if (n > 0) {
            log.info("Yorum sayaclari onarildi: satir={}", n);
        }
    }
}
