package edu.bingol.backend.accessban;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.dbmaint.ChunkedDeleter;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * KVKK: IP iceren cihaz gunlugu ve engellenen deneme gunlugu `app.security.ban-log-retention-days` (varsayilan 90)
 * gunden sonra silinir. Her gece 04:30 (Europe/Istanbul); cok ornekte {@link SchedulerLock} ile tek ornek calisir.
 *
 * <p>FIX-P02/A01#3: silme PARCALIdir ({@link ChunkedDeleter}: parca basina kisa islem, parca zaman asimi 60 sn).
 * Eskiden tek DELETE milyonlarca satirda 8 sn `statement_timeout`'a takilip yalniz log.warn ile yutuluyor, tablo
 * sinirsiz buyuyor ve 90 gun sozu tutulmuyordu. Parca hatasi artik gorevi BASARISIZ yapar ({@link #scheduled}
 * istisna firlatir: JobMonitor son hata + bu_scheduler_errors), sonraki gece kaldigi yerden devam eder.
 */
@Component
public class AccessBanRetentionJob {

    private static final Logger log = LoggerFactory.getLogger(AccessBanRetentionJob.class);

    static final String DEVICE_LOG_SQL = "DELETE FROM user_device_log WHERE id IN "
            + "(SELECT id FROM user_device_log WHERE last_seen_at < :cutoff ORDER BY id LIMIT :lim)";
    static final String ATTEMPT_LOG_SQL = "DELETE FROM blocked_attempt_log WHERE id IN "
            + "(SELECT id FROM blocked_attempt_log WHERE attempted_at < :cutoff ORDER BY id LIMIT :lim)";

    private final ChunkedDeleter deleter;
    private final SchedulerLock lock;
    private final Clock clock;
    private final int days;

    public AccessBanRetentionJob(ChunkedDeleter deleter, SchedulerLock lock, Clock clock,
                                 @Value("${app.security.ban-log-retention-days:90}") int days) {
        this.deleter = deleter;
        this.lock = lock;
        this.clock = clock;
        this.days = days;
    }

    @Scheduled(cron = "${app.security.ban-log-cleanup-cron:0 30 4 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        lock.tryRun("access-ban-retention", Duration.ofMinutes(30), () -> run(clock.instant()));
    }

    /**
     * @return silinen toplam satir. Parca hatasi olursa o ana kadar silinenler korunur ve IllegalStateException
     *         firlatilir (gorev "basarisiz" gorunur; sonraki calisma devam eder).
     */
    public int run(Instant now) {
        Instant cutoff = now.minus(days, ChronoUnit.DAYS);
        Map<String, Object> params = Map.of("cutoff", Timestamp.from(cutoff));
        long failedBefore = deleter.failedChunks();
        int n = deleter.deleteHeavy("user_device_log", DEVICE_LOG_SQL, params)
                + deleter.deleteHeavy("blocked_attempt_log", ATTEMPT_LOG_SQL, params);
        if (n > 0) {
            log.info("Erisim engeli gunluk temizligi: {} satir silindi", n);
        }
        long failed = deleter.failedChunks() - failedBefore;
        if (failed > 0) {
            throw new IllegalStateException("access-ban-retention: " + failed + " silme parcasi basarisiz (ayrinti log'da)");
        }
        return n;
    }
}
