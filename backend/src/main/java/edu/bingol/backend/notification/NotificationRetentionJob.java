package edu.bingol.backend.notification;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Saklama suresi: okunmus bildirimler `app.notification.retention-days` (varsayilan 90) sonra,
 * hic okunmamislar `app.notification.unread-retention-days` (varsayilan 365) sonra silinir. Gece 03:30 (Istanbul).
 */
@Component
public class NotificationRetentionJob {

    private static final Logger log = LoggerFactory.getLogger(NotificationRetentionJob.class);

    private final NotificationRepository notifications;
    private final int readDays;
    private final int unreadDays;

    public NotificationRetentionJob(NotificationRepository notifications,
                                    @Value("${app.notification.retention-days:90}") int readDays,
                                    @Value("${app.notification.unread-retention-days:365}") int unreadDays) {
        this.notifications = notifications;
        this.readDays = readDays;
        this.unreadDays = unreadDays;
    }

    @Scheduled(cron = "${app.notification.retention-cron:0 30 3 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        run(Instant.now());
    }

    /** @return silinen toplam satir; hata cagirana sizmaz. */
    public int run(Instant now) {
        try {
            int a = readDays > 0 ? notifications.deleteReadBefore(now.minus(readDays, ChronoUnit.DAYS)) : 0;
            int b = unreadDays > 0 ? notifications.deleteUnreadBefore(now.minus(unreadDays, ChronoUnit.DAYS)) : 0;
            if (a + b > 0) {
                log.info("Bildirim saklama: {} okunmus, {} okunmamis silindi", a, b);
            }
            return a + b;
        } catch (RuntimeException e) {
            log.warn("Bildirim saklama gorevi basarisiz: {}", e.toString());
            return 0;
        }
    }
}
