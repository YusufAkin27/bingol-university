package edu.bingol.backend.messaging;

import edu.bingol.backend.dbmaint.ChunkedDeleter;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Silinen mesajlarin saklama suresi (T24). `app.chat.deleted-retention-days` = 0 ise silinen mesajlar suresiz
 * saklanir ve is hicbir sey yapmaz; N > 0 ise N gunden eski silinmis mesajlar (tepki ve duzenleme gecmisiyle
 * birlikte) her gece kalici silinir. Hata exception sizdirmaz.
 *
 * <p>FIX-P03: silme {@link ChunkedDeleter} ile parca parca yapilir (tek DELETE 8 sn `statement_timeout` altinda
 * iptal olup ertesi gun daha buyuk kumeyle tekrar basarisiz oluyordu). Yeni bir saklama suresi EKLENMEZ.
 */
@Component
public class DeletedMessageRetention {

    /** Coklu ornek kilidi (DATABASE.md sorgu kurali 9.4); yoksa (testler/elle kurulum) eski davranis: kilitsiz calisir. */
    private edu.bingol.backend.config.SchedulerLock lock;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setLock(edu.bingol.backend.config.SchedulerLock lock) {
        this.lock = lock;
    }

    private void locked(String name, int minutes, Runnable job) {
        if (lock == null) {
            job.run();
        } else {
            lock.tryRunOrLocal(name, java.time.Duration.ofMinutes(minutes), job);
        }
    }

    private static final Logger log = LoggerFactory.getLogger(DeletedMessageRetention.class);

    static final String CHUNK_SQL = "DELETE FROM message WHERE id IN (SELECT id FROM message "
            + "WHERE deleted_at IS NOT NULL AND deleted_at < :cutoff ORDER BY id LIMIT :lim)";

    private final MessageRepository messages;
    private final Clock clock;
    private final long retentionDays;
    private final ChunkedDeleter deleter;

    public DeletedMessageRetention(MessageRepository messages, Clock clock, long retentionDays) {
        this(messages, clock, retentionDays, null);
    }

    @Autowired
    public DeletedMessageRetention(MessageRepository messages, Clock clock,
                                   @Value("${app.chat.deleted-retention-days:0}") long retentionDays,
                                   ChunkedDeleter deleter) {
        this.messages = messages;
        this.clock = clock;
        this.retentionDays = Math.max(0, retentionDays);
        this.deleter = deleter;
    }

    @Scheduled(cron = "${app.chat.deleted-retention-cron:0 40 3 * * *}", zone = "Europe/Istanbul")
    public void scheduledPurge() {
        locked("deleted-message-retention", 60, this::purge);
    }

    public void purge() {
        if (retentionDays == 0) {
            return;
        }
        try {
            Instant cutoff = clock.instant().minus(Duration.ofDays(retentionDays));
            int n = deleter == null ? messages.purgeDeletedBefore(cutoff)
                    : deleter.delete("message_deleted", CHUNK_SQL,
                            Map.of("cutoff", OffsetDateTime.ofInstant(cutoff, ZoneOffset.UTC)));
            log.info("Silinen mesaj saklama: {} mesaj kalici silindi (sure {} gun)", n, retentionDays);
        } catch (RuntimeException e) {
            log.warn("Silinen mesaj temizligi basarisiz: {}", e.toString());
        }
    }
}
