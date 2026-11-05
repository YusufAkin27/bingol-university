package edu.bingol.backend.forum.media;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Zamanlanmis temizlik: konuya baglanmamis yuklemeler (24 sa) ve silinmis konularin gorselleri (30 gun). */
@Component
public class ForumMediaJanitor {

    private static final Logger log = LoggerFactory.getLogger(ForumMediaJanitor.class);

    private final ForumMediaService service;
    private final SchedulerLock lock;
    private final int unattachedHours;

    public ForumMediaJanitor(ForumMediaService service, SchedulerLock lock,
                             @Value("${app.forum.media.unattached-hours:24}") int unattachedHours) {
        this.service = service;
        this.lock = lock;
        this.unattachedHours = Math.max(1, unattachedHours);
    }

    @Scheduled(cron = "${app.forum.media.cleanup-cron:0 35 * * * *}", zone = "Europe/Istanbul")
    public void unattached() {
        lock.tryRun("forum-media-unattached", Duration.ofMinutes(50), () -> {
            int n = service.sweepUnattached(Duration.ofHours(unattachedHours));
            if (n > 0) {
                log.info("Forum gorsel temizligi: {} baglanmamis yukleme silindi", n);
            }
        });
    }

    @Scheduled(cron = "${app.forum.media.deleted-cleanup-cron:0 50 4 * * *}", zone = "Europe/Istanbul")
    public void deleted() {
        lock.tryRun("forum-media-deleted", Duration.ofMinutes(50), () -> {
            int n = service.sweepDeleted();
            if (n > 0) {
                log.info("Forum gorsel temizligi: {} silinmis konu gorseli kaldirildi", n);
            }
        });
    }
}
