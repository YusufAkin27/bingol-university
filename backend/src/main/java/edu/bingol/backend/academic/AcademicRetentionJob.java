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
 * Akademik veri saklama (FIX-P08, A07#9 / K23): bitmis donemler ve suresi dolmus duyurular sonsuza dek birikmesin.
 * Her silme {@link ChunkedDeleter} ile parcali ve birbirinden bagimsizdir (biri duserse digerleri calisir).
 *
 * <ul>
 *   <li>{@code announcement_read}: suresi {@code read-retention-days} (90) gun once dolmus duyurularin okundu satirlari;</li>
 *   <li>{@code department_announcement}: suresi {@code retention-days} (365) gun once dolmus duyurular
 *       (okundu satirlari ON DELETE CASCADE ile gider);</li>
 *   <li>{@code exam_schedule}, {@code academic_event}: bitisi (yoksa baslangici) {@code retention-days} gunden eski;</li>
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
    private final int readRetentionDays;

    @Autowired
    public AcademicRetentionJob(ChunkedDeleter deleter, SchedulerLock lock,
                                @Value("${app.academic.retention-days:365}") int retentionDays,
                                @Value("${app.academic.read-retention-days:90}") int readRetentionDays) {
        this(deleter, lock, Clock.systemUTC(), retentionDays, readRetentionDays);
    }

    AcademicRetentionJob(ChunkedDeleter deleter, SchedulerLock lock, Clock clock, int retentionDays, int readRetentionDays) {
        this.deleter = deleter;
        this.lock = lock;
        this.clock = clock;
        this.retentionDays = retentionDays;
        this.readRetentionDays = readRetentionDays;
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
        if (readRetentionDays > 0) {
            Timestamp cutoff = Timestamp.from(now.minus(Duration.ofDays(readRetentionDays)));
            out.put("announcement_read", deleter.delete("announcement_read",
                    "DELETE FROM announcement_read WHERE (announcement_id, user_id) IN (SELECT r.announcement_id, r.user_id "
                            + "FROM announcement_read r JOIN department_announcement a ON a.id = r.announcement_id "
                            + "WHERE a.expires_at IS NOT NULL AND a.expires_at < :cutoff LIMIT :lim)",
                    Map.of("cutoff", cutoff)));
        }
        if (retentionDays > 0) {
            Timestamp cutoff = Timestamp.from(now.minus(Duration.ofDays(retentionDays)));
            LocalDate cutoffDate = LocalDate.ofInstant(now, AcademicTime.ZONE).minusDays(retentionDays);
            out.put("department_announcement", deleter.delete("department_announcement",
                    "DELETE FROM department_announcement WHERE id IN (SELECT id FROM department_announcement "
                            + "WHERE expires_at IS NOT NULL AND expires_at < :cutoff LIMIT :lim)", Map.of("cutoff", cutoff)));
            out.put("exam_schedule", deleter.delete("exam_schedule",
                    "DELETE FROM exam_schedule WHERE id IN (SELECT id FROM exam_schedule "
                            + "WHERE COALESCE(ends_at, starts_at) < :cutoff LIMIT :lim)", Map.of("cutoff", cutoff)));
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
