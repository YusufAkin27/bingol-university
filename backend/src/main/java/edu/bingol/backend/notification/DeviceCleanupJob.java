package edu.bingol.backend.notification;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Uygulama `app.push.device-ttl-days` (varsayilan 60) gundur acilmayan cihaz token'larini siler. Gece 04:00. */
@Component
public class DeviceCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(DeviceCleanupJob.class);

    private final DeviceRepository devices;
    private final int ttlDays;

    public DeviceCleanupJob(DeviceRepository devices, @Value("${app.push.device-ttl-days:60}") int ttlDays) {
        this.devices = devices;
        this.ttlDays = ttlDays;
    }

    @Scheduled(cron = "${app.push.device-cleanup-cron:0 0 4 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        run(Instant.now());
    }

    /** @return silinen cihaz sayisi; hata cagirana sizmaz. */
    public int run(Instant now) {
        try {
            int n = ttlDays > 0 ? devices.deleteStale(now.minus(ttlDays, ChronoUnit.DAYS)) : 0;
            if (n > 0) {
                log.info("Eski cihaz temizligi: {} token silindi", n);
            }
            return n;
        } catch (RuntimeException e) {
            log.warn("Cihaz temizligi basarisiz: {}", e.toString());
            return 0;
        }
    }
}
