package edu.bingol.backend.post.reels;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/** İzleme geçmişi saklama (varsayılan 45 gün; her gece 05:20 Europe/Istanbul, SchedulerLock). Hata çağırana sızmaz. */
@Component
public class PostWatchRetentionJob {

    private static final Logger log = LoggerFactory.getLogger(PostWatchRetentionJob.class);

    private final PostWatchRepository repo;
    private final ReelsProperties props;
    private final SchedulerLock lock;
    private final Clock clock;
    private final TransactionTemplate tx;

    public PostWatchRetentionJob(PostWatchRepository repo, ReelsProperties props, SchedulerLock lock, Clock clock,
                                 TransactionTemplate tx) {
        this.repo = repo;
        this.props = props;
        this.lock = lock;
        this.clock = clock;
        this.tx = tx;
    }

    @Scheduled(cron = "${app.post.reels.retention-cron:0 20 5 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        try {
            lock.tryRun("post-watch-retention", Duration.ofMinutes(20), () -> run(clock.instant()));
        } catch (RuntimeException e) {
            log.warn("Izleme gecmisi saklama isi basarisiz: {}", e.toString());
        }
    }

    /** @return silinen satır sayısı. */
    public int run(Instant now) {
        Integer n = tx.execute(s -> repo.deleteOlderThan(now.minus(Math.max(1, props.retentionDays()), ChronoUnit.DAYS)));
        return n == null ? 0 : n;
    }
}
