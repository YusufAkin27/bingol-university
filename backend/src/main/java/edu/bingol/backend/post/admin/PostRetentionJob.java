package edu.bingol.backend.post.admin;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.post.PostDeletedEvent;
import edu.bingol.backend.post.spi.PostMediaBinder;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Kesfet gonderileri icin kalici temizlik (her gece 05:10, Europe/Istanbul; coklu ornekte SchedulerLock).
 * 1) `hidden-days` (varsayilan 30; 0 = kapali) gundur gizli kalan gonderiler yumusak silinir (PostDeletedEvent;
 *    itiraz suresi bitti). 2) `deleted-days` (varsayilan 30) gundur silinmis gonderiler satirlariyla birlikte
 *    (yorum/begeni ON DELETE CASCADE) KALICI silinir. Medya baytlari ve satirlari PostMediaJanitor'un (04:40)
 *    isidir: medya satiri hala duran gonderi atlanir, bir sonraki gece denenir. Hata cagirana sizmaz.
 */
@Component
public class PostRetentionJob {

    private static final Logger log = LoggerFactory.getLogger(PostRetentionJob.class);
    static final int BATCH = 500;
    static final int MAX_BATCHES = 20;

    private final JdbcTemplate jdbc;
    private final SchedulerLock lock;
    private final Clock clock;
    private final ApplicationEventPublisher events;
    private final ObjectProvider<PostMediaBinder> binder;
    private final int hiddenDays;
    private final int deletedDays;

    public PostRetentionJob(JdbcTemplate jdbc, SchedulerLock lock, Clock clock, ApplicationEventPublisher events,
                            ObjectProvider<PostMediaBinder> binder,
                            @Value("${app.post.retention.hidden-days:30}") int hiddenDays,
                            @Value("${app.post.retention.deleted-days:30}") int deletedDays) {
        this.jdbc = jdbc;
        this.lock = lock;
        this.clock = clock;
        this.events = events;
        this.binder = binder;
        this.hiddenDays = hiddenDays;
        this.deletedDays = Math.max(0, deletedDays);
    }

    @Scheduled(cron = "${app.post.retention.cron:0 10 5 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        lock.tryRun("post-retention", Duration.ofMinutes(30), () -> run(clock.instant()));
    }

    /** @return kalici silinen gonderi sayisi. */
    public int run(Instant now) {
        try {
            if (hiddenDays > 0) {
                softDeleteLongHidden(now.minus(hiddenDays, ChronoUnit.DAYS));
            }
            int total = 0;
            Timestamp cutoff = Timestamp.from(now.minus(deletedDays, ChronoUnit.DAYS));
            for (int i = 0; i < MAX_BATCHES; i++) {
                int n = jdbc.update("DELETE FROM post WHERE id IN (SELECT p.id FROM post p WHERE p.deleted_at IS NOT NULL "
                        + "AND p.deleted_at < ? AND NOT EXISTS (SELECT 1 FROM post_media m WHERE m.post_id = p.id) "
                        + "ORDER BY p.id LIMIT " + BATCH + ")", cutoff);
                total += n;
                if (n < BATCH) {
                    break;
                }
            }
            if (total > 0) {
                log.info("Gonderi saklama temizligi: {} gonderi kalici silindi", total);
            }
            return total;
        } catch (RuntimeException e) {
            log.warn("Gonderi saklama temizligi basarisiz: {}", e.toString());
            return 0;
        }
    }

    private void softDeleteLongHidden(Instant before) {
        List<Long> ids = jdbc.queryForList("SELECT id FROM post WHERE hidden_at IS NOT NULL AND hidden_at < ? "
                + "AND deleted_at IS NULL ORDER BY id LIMIT " + (BATCH * MAX_BATCHES), Long.class, Timestamp.from(before));
        PostMediaBinder b = binder.getIfAvailable();
        for (Long id : ids) {
            int n = jdbc.update("UPDATE post SET deleted_at = ? WHERE id = ? AND deleted_at IS NULL",
                    Timestamp.from(clock.instant()), id);
            if (n > 0) {
                events.publishEvent(new PostDeletedEvent(id, b == null ? List.of() : b.mediaIdsOf(id)));
            }
        }
    }
}
