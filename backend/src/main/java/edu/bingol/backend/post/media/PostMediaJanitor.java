package edu.bingol.backend.post.media;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Zamanlanmis temizlik: baglanmamis yuklemeler (24 sa) ve silinmis gonderilerin medyasi (30 gun).
 * Coklu ornekte cift tarama olmasin diye SchedulerLock ile sarilidir (diger post isleri gibi).
 */
@Component
public class PostMediaJanitor {

    private static final Logger log = LoggerFactory.getLogger(PostMediaJanitor.class);

    private final PostMediaService service;
    private final SchedulerLock lock;
    private final int unattachedHours;

    public PostMediaJanitor(PostMediaService service, SchedulerLock lock,
                            @Value("${app.post.media.unattached-hours:24}") int unattachedHours) {
        this.service = service;
        this.lock = lock;
        this.unattachedHours = Math.max(1, unattachedHours);
    }

    @Scheduled(cron = "${app.post.media.cleanup-cron:0 25 * * * *}", zone = "Europe/Istanbul")
    public void unattached() {
        lock.tryRun("post-media-unattached", Duration.ofMinutes(50), () -> {
            int n = service.sweepUnattached(Duration.ofHours(unattachedHours));
            if (n > 0) {
                log.info("Gonderi medyasi temizligi: {} baglanmamis yukleme silindi", n);
            }
        });
    }

    @Scheduled(cron = "${app.post.media.deleted-cleanup-cron:0 40 4 * * *}", zone = "Europe/Istanbul")
    public void deleted() {
        lock.tryRun("post-media-deleted", Duration.ofMinutes(50), () -> {
            int n = service.sweepDeleted();
            if (n > 0) {
                log.info("Gonderi medyasi temizligi: {} silinmis gonderi medyasi kaldirildi", n);
            }
        });
    }
}
