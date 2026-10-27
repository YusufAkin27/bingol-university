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
        try {
            ProfanityHitLog h = new ProfanityHitLog();
            h.setEntity(entity);
            h.setField(field);
            h.setUserId(userId);
            h.setAction(action);
            repo.save(h);
        } catch (RuntimeException e) {
            log.warn("Uygunsuz ifade gunlugu yazilamadi: {}", e.getClass().getSimpleName()); // kelime asla loglanmaz
        }
    }

    @Scheduled(cron = "0 30 4 * * *", zone = "Europe/Istanbul")
    @Transactional
    public void purgeOld() {
        try {
            repo.deleteOlderThan(Instant.now().minus(Duration.ofDays(RETENTION_DAYS)));
        } catch (RuntimeException e) {
            log.warn("Uygunsuz ifade gunlugu temizlenemedi: {}", e.getClass().getSimpleName());
        }
    }
}
