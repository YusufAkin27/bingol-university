package edu.bingol.backend.event;

import edu.bingol.backend.config.SchedulerLock;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * FIX-P05 (A05#2): gece uzlastirmasi. {@code user_event.going_count} denormalize sayacini GOING RSVP satir sayisina
 * esitler; yaris/hata kaynakli "hayalet koltuk" ya da fazla rezervasyon kendiliginden onarilir.
 *
 * <p>Her etkinlik KENDI kisa islemindedir: once satir kilitlenir ({@code FOR UPDATE}; bu sirada yeni RSVP sayaci
 * bekler), sonra sayim yeniden okunur ve yazilir. Boylece uzlastirma, eszamanli bir RSVP'nin sayacini ezemez.
 * Yalniz bitmemis ACTIVE/PENDING_REVIEW etkinlikler; calisma basina en cok {@value #MAX_PER_RUN} duzeltme.
 */
@Component
public class EventGoingCountReconciler {

    private static final Logger log = LoggerFactory.getLogger(EventGoingCountReconciler.class);
    static final int MAX_PER_RUN = 500;

    private final JdbcTemplate jdbc;
    private final TransactionTemplate tx;
    private final SchedulerLock lock;

    public EventGoingCountReconciler(JdbcTemplate jdbc, PlatformTransactionManager tm, SchedulerLock lock) {
        this.jdbc = jdbc;
        this.tx = new TransactionTemplate(tm);
        this.lock = lock;
    }

    @Scheduled(cron = "${app.event.going-reconcile-cron:0 20 3 * * *}", zone = "Europe/Istanbul")
    public void nightly() {
        try {
            lock.tryRun("event-going-reconcile", Duration.ofMinutes(10), () -> {
                int n = reconcile(Instant.now());
                if (n > 0) {
                    log.info("Etkinlik katilimci sayaci uzlastirildi: {} etkinlik duzeltildi", n);
                }
            });
        } catch (RuntimeException e) {
            log.warn("Etkinlik katilimci sayaci uzlastirilamadi: {}", e.toString());
        }
    }

    /** @return duzeltilen etkinlik sayisi */
    public int reconcile(Instant now) {
        List<Long> drift = jdbc.queryForList("""
                SELECT e.id FROM user_event e
                WHERE e.status IN ('ACTIVE', 'PENDING_REVIEW') AND e.ends_at > ?
                  AND e.going_count <> (SELECT COUNT(*) FROM event_rsvp r WHERE r.event_id = e.id AND r.status = 'GOING')
                ORDER BY e.id LIMIT ?
                """, Long.class, Timestamp.from(now), MAX_PER_RUN);
        int fixed = 0;
        for (Long id : drift) {
            try {
                Integer changed = tx.execute(s -> {
                    // Kilit once: bu noktadan sonra yeni RSVP sayaci bekler; sayim kilitten SONRA okunur.
                    jdbc.queryForList("SELECT going_count FROM user_event WHERE id = ? FOR UPDATE", Integer.class, id);
                    return jdbc.update("""
                            UPDATE user_event SET going_count =
                                (SELECT COUNT(*) FROM event_rsvp r WHERE r.event_id = user_event.id AND r.status = 'GOING')
                            WHERE id = ?
                              AND going_count <> (SELECT COUNT(*) FROM event_rsvp r2 WHERE r2.event_id = user_event.id AND r2.status = 'GOING')
                            """, id);
                });
                if (changed != null && changed > 0) {
                    fixed++;
                }
            } catch (RuntimeException e) {
                // Tek etkinligin (ornegin kapasite CHECK'i) hatasi digerlerini durdurmaz.
                log.warn("Etkinlik {} sayaci uzlastirilamadi: {}", id, e.toString());
            }
        }
        return fixed;
    }
}
