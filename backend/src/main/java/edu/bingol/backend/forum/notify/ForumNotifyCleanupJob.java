package edu.bingol.backend.forum.notify;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.dbmaint.ChunkedDeleter;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Gece 03:40 (Europe/Istanbul): forum bildirim tekrar defterinde ({@code forum_notify_seen}) {@code app.forum.notify-seen-retention-days}
 * (varsayilan 90) gunden eski satirlari parcali siler. 90 gunden sonra ayni kisi ayni konuyu yeniden begenirse bildirim
 * tekrar gidebilir (kabul edilen sinir). Cok ornekte {@link SchedulerLock} ile tek ornek; hata cagirana sizmaz.
 */
@Component
public class ForumNotifyCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(ForumNotifyCleanupJob.class);

    static final String DELETE_SQL = "DELETE FROM forum_notify_seen WHERE (kind, target_id, actor_id, recipient_user_id) IN "
            + "(SELECT kind, target_id, actor_id, recipient_user_id FROM forum_notify_seen WHERE created_at < :cutoff LIMIT :lim)";

    private final ChunkedDeleter deleter;
    private final SchedulerLock lock;
    private final int retentionDays;

    public ForumNotifyCleanupJob(ChunkedDeleter deleter, SchedulerLock lock,
                                 @Value("${app.forum.notify-seen-retention-days:90}") int retentionDays) {
        this.deleter = deleter;
        this.lock = lock;
        this.retentionDays = retentionDays;
    }

    @Scheduled(cron = "${app.forum.notify-cleanup-cron:0 40 3 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        lock.tryRunOrLocal("forum-notify-seen-cleanup", Duration.ofMinutes(30), () -> run(Instant.now()));
    }

    /** @return silinen satir sayisi; saklama kapaliysa (&lt;=0) 0. */
    public int run(Instant now) {
        if (retentionDays <= 0) {
            return 0;
        }
        try {
            int n = deleter.delete("forum_notify_seen", DELETE_SQL,
                    Map.of("cutoff", Timestamp.from(now.minus(Duration.ofDays(retentionDays)))));
            if (n > 0) {
                log.info("Forum bildirim defteri temizligi: {} satir silindi", n);
            }
            return n;
        } catch (RuntimeException e) {
            log.warn("Forum bildirim defteri temizligi basarisiz: {}", e.toString());
            return 0;
        }
    }
}
