package edu.bingol.backend.analytics;

import java.time.Clock;
import java.time.Duration;
import java.time.ZoneOffset;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Her gece 03:15 (Istanbul): 180 gunden eski analitik olaylari siler. Hata exception sizdirmaz. */
@Component
public class EventRetention {

    private static final Logger log = LoggerFactory.getLogger(EventRetention.class);
    private static final int DELETE_BATCH = 10_000;

    private final ActivityRepository repo;
    private final Clock clock;

    public EventRetention(ActivityRepository repo, Clock clock) {
        this.repo = repo;
        this.clock = clock;
    }

    @Scheduled(cron = "${analytics.retention.cron:0 15 3 * * *}", zone = "Europe/Istanbul")
    public void purge() {
        try {
            int n = repo.deleteEventsOlderThan(
                    clock.instant().minus(Duration.ofDays(AnalyticsConfig.EVENT_RETENTION_DAYS)).atOffset(ZoneOffset.UTC),
                    DELETE_BATCH);
            log.info("Analitik olay saklama: {} kayit silindi", n);
        } catch (RuntimeException e) {
            log.warn("Analitik olay temizligi basarisiz: {}", e.toString());
        }
    }
}
