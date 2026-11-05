package edu.bingol.backend.academic;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.dbmaint.ChunkedDeleter;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Akademik veri saklama (FIX-P08, A07#9 / K23): bitmis donemler ve eski sinav/takvim kayitlari sonsuza dek birikmesin.
 * Her silme {@link ChunkedDeleter} ile parcali ve birbirinden bagimsizdir (biri duserse digerleri calisir).
 *
 * <ul>
 *   <li>{@code academic_event}: bitisi (yoksa baslangici) {@code retention-days} gunden eski;</li>
 *   <li>{@code tt_exam} (kisisel sinavlar): baslangici {@code retention-days} gunden eski;</li>
 *   <li>{@code tt_course} (+ oturumlari CASCADE) ve {@code tt_semester}: bitis tarihi {@code retention-days} gunden eski donemler.</li>
 * </ul>
 * 0 = o grup kapali. Yeni gonderim/bildirim uretmez; yalniz eski kayitlari siler.
 */
@Component
public class AcademicRetentionJob {

    private static final Logger log = LoggerFactory.getLogger(AcademicRetentionJob.class);

    private final ChunkedDeleter deleter;
    private final SchedulerLock lock;
    private final Clock clock;
    private final int retentionDays;

    @Autowired
    public AcademicRetentionJob(ChunkedDeleter deleter, SchedulerLock lock,
                                @Value("${app.academic.retention-days:365}") int retentionDays) {
        this(deleter, lock, Clock.systemUTC(), retentionDays);
    }

    AcademicRetentionJob(ChunkedDeleter deleter, SchedulerLock lock, Clock clock, int retentionDays) {
        this.deleter = deleter;
        this.lock = lock;
        this.clock = clock;
        this.retentionDays = retentionDays;
    }

    @Scheduled(cron = "${app.academic.retention-cron:0 30 3 * * *}", zone = "Europe/Istanbul")
    public void nightly() {
        try {
            if (lock == null) {
                runAll();
            } else {
                lock.tryRun("academic-retention", Duration.ofMinutes(30), this::runAll);
            }
        } catch (RuntimeException e) {
            log.warn("Akademik saklama gorevi basarisiz: {}", e.toString());
        }
    }

    /** @return grup adi -> silinen satir. Hata cagirana sizmaz (ChunkedDeleter parca hatasini sayar ve loglar). */
    public Map<String, Integer> runAll() {
        Instant now = clock.instant();
        Map<String, Integer> out = new LinkedHashMap<>();
        if (retentionDays > 0) {
            Timestamp cutoff = Timestamp.from(now.minus(Duration.ofDays(retentionDays)));
            LocalDate cutoffDate = LocalDate.ofInstant(now, AcademicTime.ZONE).minusDays(retentionDays);
            out.put("academic_event", deleter.delete("academic_event",
                    "DELETE FROM academic_event WHERE id IN (SELECT id FROM academic_event "
                            + "WHERE COALESCE(ends_at, starts_at) < :cutoff LIMIT :lim)", Map.of("cutoff", cutoff)));
            out.put("tt_exam", deleter.delete("tt_exam",
                    "DELETE FROM tt_exam WHERE id IN (SELECT id FROM tt_exam WHERE starts_at < :cutoff LIMIT :lim)",
                    Map.of("cutoff", cutoff)));
            // Dersler once (oturumlari CASCADE, tt_exam.course_id SET NULL), sonra dersi kalmayan eski donemler
            out.put("tt_course", deleter.delete("tt_course",
                    "DELETE FROM tt_course WHERE id IN (SELECT c.id FROM tt_course c JOIN tt_semester s ON s.id = c.semester_id "
                            + "WHERE s.end_date < :cutoff LIMIT :lim)", Map.of("cutoff", cutoffDate)));
            out.put("tt_semester", deleter.delete("tt_semester",
                    "DELETE FROM tt_semester WHERE id IN (SELECT s.id FROM tt_semester s WHERE s.end_date < :cutoff "
                            + "AND NOT EXISTS (SELECT 1 FROM tt_course c WHERE c.semester_id = s.id) LIMIT :lim)",
                    Map.of("cutoff", cutoffDate)));
        }
        return out;
    }
}
