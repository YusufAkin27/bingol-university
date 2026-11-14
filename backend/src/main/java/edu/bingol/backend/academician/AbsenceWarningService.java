package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AttendanceMath.Result;
import java.time.Clock;
import java.util.Collection;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Otomatik devamsizlik uyarisi. Hesap {@link AttendanceMath} ile (canli/sayilmayan/kayit oncesi/izinli oturumlar sayilmaz).
 * Her duzey ogrenciye BIR kez bildirilir (ac_enrollment.warned_level, kosullu UPDATE ile: es zamanli iki cagri cift bildirim
 * vermez). Duzey, hocanin kayit duzeltmesi / oturum silme-sayma degisikligi / sinir degisikligi sonrasi sessizce DUSURULEBILIR
 * ({@code lower=true}); oturum kesinlesme, acma ve yeniden acma akislarinda dusurulmez (yeniden acma cift uyari uretmesin).
 */
@Service
public class AbsenceWarningService {

    private static final Logger log = LoggerFactory.getLogger(AbsenceWarningService.class);

    private final AcCourseRepository courses;
    private final AcEnrollmentRepository enrollments;
    private final AttendanceStats stats;
    private final AcademicianNotifier notifier;
    private final Clock clock;
    private final TransactionTemplate tx;

    public AbsenceWarningService(AcCourseRepository courses, AcEnrollmentRepository enrollments, AttendanceStats stats,
                                 AcademicianNotifier notifier, Clock clock, PlatformTransactionManager tm) {
        this.courses = courses;
        this.enrollments = enrollments;
        this.stats = stats;
        this.notifier = notifier;
        this.clock = clock;
        this.tx = new TransactionTemplate(tm);
    }

    /** Kesinlestirme/acma/yeniden acma: yalniz yukselir (dusurmez). */
    public void recompute(Long courseId) {
        recompute(courseId, null, false);
    }

    /** Duzeltme/silme/sayma/sinir degisimi: duzey dusebilir. */
    public void recomputeLowering(Long courseId, Collection<Long> onlyStudents) {
        recompute(courseId, onlyStudents, true);
    }

    /** {@code onlyStudents} null ise hepsi. Hata cagirana sizmaz. */
    public void recompute(Long courseId, Collection<Long> onlyStudents, boolean lower) {
        try {
            AcCourse c = courses.findById(courseId).orElse(null);
            if (c == null) {
                return;
            }
            for (var e : stats.forCourse(c, onlyStudents, clock.instant()).byStudent().entrySet()) {
                apply(c, e.getKey(), e.getValue(), lower);
            }
        } catch (RuntimeException ex) {
            log.warn("Devamsizlik uyarisi hesaplanamadi courseId={}: {}", courseId, ex.toString());
        }
    }

    private void apply(AcCourse c, Long studentId, Result r, boolean lower) {
        int level = r.level();
        Integer raised = tx.execute(s -> level > 0 ? enrollments.raiseWarned(c.getId(), studentId, (short) level) : 0);
        if (raised != null && raised > 0) {
            // bu cagri duzeyi yukseltti: bildirim yalniz bir kez gider
            notifier.absence(c, studentId, level, r.absent());
        }
        if (lower) {
            tx.executeWithoutResult(s -> enrollments.lowerWarned(c.getId(), studentId, (short) level));
        }
    }

    /** Sinir metni: COUNT "4", PERCENT "%20". */
    static String limitText(AcCourse c) {
        if (c.getAbsenceLimitType() == null || c.getAbsenceLimitValue() == null) {
            return "";
        }
        Integer allowed = AbsencePolicy.allowedAbsences(c.getAbsenceLimitType(), c.getAbsenceLimitValue().intValue(),
                c.getPlannedSessions() == null ? null : c.getPlannedSessions().intValue());
        if (allowed != null) {
            return String.valueOf(allowed);
        }
        return "%" + c.getAbsenceLimitValue();
    }
}
