package edu.bingol.backend.accessban;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * KVKK: IP iceren cihaz gunlugu ve engellenen deneme gunlugu `app.security.ban-log-retention-days` (varsayilan 90)
 * gunden sonra silinir. Her gece 04:30 (Europe/Istanbul); cok ornekte {@link SchedulerLock} ile tek ornek calisir.
 */
@Component
public class AccessBanRetentionJob {

    private static final Logger log = LoggerFactory.getLogger(AccessBanRetentionJob.class);

    private final UserDeviceLogRepository deviceLogs;
    private final BlockedAttemptLogRepository attempts;
    private final SchedulerLock lock;
    private final Clock clock;
    private final int days;

    public AccessBanRetentionJob(UserDeviceLogRepository deviceLogs, BlockedAttemptLogRepository attempts,
                                 SchedulerLock lock, Clock clock,
                                 @Value("${app.security.ban-log-retention-days:90}") int days) {
        this.deviceLogs = deviceLogs;
        this.attempts = attempts;
        this.lock = lock;
        this.clock = clock;
        this.days = days;
    }

    @Scheduled(cron = "${app.security.ban-log-cleanup-cron:0 30 4 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        lock.tryRun("access-ban-retention", Duration.ofMinutes(30), () -> run(clock.instant()));
    }

    /** @return silinen toplam satir; hata cagirana sizmaz. */
    public int run(Instant now) {
        try {
            Instant cutoff = now.minus(days, ChronoUnit.DAYS);
            int n = deviceLogs.deleteOlderThan(cutoff) + attempts.deleteOlderThan(cutoff);
            if (n > 0) {
                log.info("Erisim engeli gunluk temizligi: {} satir silindi", n);
            }
            return n;
        } catch (RuntimeException e) {
            log.warn("Erisim engeli gunluk temizligi basarisiz: {}", e.toString());
            return 0;
        }
    }
}
