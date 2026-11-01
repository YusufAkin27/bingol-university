package edu.bingol.backend.moderation.profanity;

import java.time.Duration;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Engelleme gunlugu: istek hata ile geri alinsa bile kayit kalsin diye ayri islemde yazilir; 90 gun saklanir. */
@Service
public class ProfanityHitLogger {

    private static final Logger log = LoggerFactory.getLogger(ProfanityHitLogger.class);
    static final int RETENTION_DAYS = 90;

    private final ProfanityHitLogRepository repo;

    public ProfanityHitLogger(ProfanityHitLogRepository repo) {
        this.repo = repo;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(String entity, String field, Long userId, String action) {
        save(entity, field, userId, action, ProfanityCategory.PROFANITY);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(String entity, String field, Long userId, String action, ProfanityCategory category) {
        save(entity, field, userId, action, category);
    }

    private void save(String entity, String field, Long userId, String action, ProfanityCategory category) {
        try {
            ProfanityHitLog h = new ProfanityHitLog();
            h.setEntity(entity);
            h.setField(field);
            h.setUserId(userId);
            h.setAction(action);
            h.setCategory(category == null ? "PROFANITY" : category.name());
            repo.save(h);
        } catch (RuntimeException e) {
            log.warn("Uygunsuz ifade gunlugu yazilamadi: {}", e.getClass().getSimpleName()); // kelime asla loglanmaz
        }
    }

    /** FIX-P05 (A05 #11): parcali silme ve coklu ornek kilidi (istege bagli; yoksa eski tek DELETE yolu). */
    private edu.bingol.backend.dbmaint.ChunkedDeleter deleter;
    private edu.bingol.backend.config.SchedulerLock lock;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    public void setMaintenance(edu.bingol.backend.dbmaint.ChunkedDeleter deleter, edu.bingol.backend.config.SchedulerLock lock) {
        this.deleter = deleter;
        this.lock = lock;
    }

    @Scheduled(cron = "0 30 4 * * *", zone = "Europe/Istanbul")
    public void purgeOld() {
        try {
            if (lock != null) {
                lock.tryRun("profanity-hit-purge", Duration.ofMinutes(15), this::doPurge);
            } else {
                doPurge();
            }
        } catch (RuntimeException e) {
            log.warn("Uygunsuz ifade gunlugu temizlenemedi: {}", e.getClass().getSimpleName());
        }
    }

    void doPurge() {
        Instant cutoff = Instant.now().minus(Duration.ofDays(RETENTION_DAYS));
        if (deleter != null) {
            deleter.delete("profanity_hit_log",
                    "DELETE FROM profanity_hit_log WHERE id IN (SELECT id FROM profanity_hit_log WHERE at < :cutoff ORDER BY id LIMIT :lim)",
                    java.util.Map.of("cutoff", java.time.OffsetDateTime.ofInstant(cutoff, java.time.ZoneOffset.UTC)));
        } else {
            repo.deleteOlderThan(cutoff); // ChunkedDeleter yoksa (elle kurulan birim testleri) eski tek DELETE
        }
    }
}
