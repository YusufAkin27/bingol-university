package edu.bingol.backend.post.follow;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Gizli hesap bakımı: hesabı artık herkese açık olan hedeflere kalmış bekleyen istekleri tamamlar (gizli → açık
 * geçişte ilk parçalar anında işlenir, çok büyük birikim buraya kalır). 90 günlük temizlik DbMaintenanceJob'dadır.
 */
@Component
public class FollowRequestJob {

    private static final Logger log = LoggerFactory.getLogger(FollowRequestJob.class);

    private final FollowRequestService requests;
    private final SchedulerLock lock;

    public FollowRequestJob(FollowRequestService requests, SchedulerLock lock) {
        this.requests = requests;
        this.lock = lock;
    }

    @Scheduled(fixedDelayString = "${app.follow.request-heal-ms:300000}", initialDelayString = "${app.follow.request-heal-ms:300000}")
    public void scheduled() {
        try {
            lock.tryRun("follow-request-heal", Duration.ofMinutes(4), () -> {
                int n = requests.healPublicTargets();
                if (n > 0) {
                    log.info("Takip istekleri: herkese acik hesaplara kalan {} istek kabul edildi", n);
                }
            });
        } catch (RuntimeException e) {
            log.warn("Takip istegi bakimi basarisiz: {}", e.toString());
        }
    }
}
