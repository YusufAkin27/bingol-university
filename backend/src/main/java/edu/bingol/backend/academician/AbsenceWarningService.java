package edu.bingol.backend.academician;

import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Otomatik devamsizlik uyarisi. Hesap yalniz KESINLESMIS (kapali) oturumlari sayar (acik, suren oturumda henuz taramamis
 * ogrenci "devamsiz" sayilmaz). Her duzey ogrenciye BIR kez bildirilir (ac_enrollment.warned_level, kosullu UPDATE ile:
 * es zamanli iki cagri cift bildirim vermez); duzeltmeyle duzey duserse bildirim yok, yalniz warned_level duser ki
 * sonraki asimda yeniden bildirilsin. Sinir degisince, kayit duzeltilince ve oturum kesinlesince ayni yol calisir.
 */
@Service
public class AbsenceWarningService {

    private static final Logger log = LoggerFactory.getLogger(AbsenceWarningService.class);

    private final AcCourseRepository courses;
    private final AcSessionRepository sessions;
    private final AcEnrollmentRepository enrollments;
    private final AcAttendanceRepository attendance;
    private final AcademicianNotifier notifier;
    private final TransactionTemplate tx;

    public AbsenceWarningService(AcCourseRepository courses, AcSessionRepository sessions, AcEnrollmentRepository enrollments,
                                 AcAttendanceRepository attendance, AcademicianNotifier notifier, PlatformTransactionManager tm) {
        this.courses = courses;
        this.sessions = sessions;
        this.enrollments = enrollments;
        this.attendance = attendance;
        this.notifier = notifier;
        this.tx = new TransactionTemplate(tm);
    }

    /** Dersin tum kayitli ogrencilerini yeniden degerlendirir. Hata cagirana sizmaz. */
    public void recompute(Long courseId) {
        recompute(courseId, null);
    }

    /** {@code onlyStudents} null ise hepsi; doluysa yalniz onlar (tek kayit duzeltmesi). */
    public void recompute(Long courseId, Collection<Long> onlyStudents) {
        try {
            AcCourse c = courses.findById(courseId).orElse(null);
            if (c == null) {
                return;
            }
            int total = (int) sessions.countByCourseIdAndStatus(courseId, AcSession.Status.CLOSED);
            Map<Long, Integer> present = new HashMap<>();
            for (Object[] r : attendance.presentInFinal(courseId, PageRequest.of(0, EnrollmentService.MAX_ENROLLED))) {
                present.put((Long) r[0], ((Number) r[1]).intValue());
            }
            Integer limit = c.getAbsenceLimitValue() == null ? null : c.getAbsenceLimitValue().intValue();
            for (AcEnrollment e : enrollments.ofCourse(courseId, PageRequest.of(0, EnrollmentService.MAX_ENROLLED))) {
                if (onlyStudents != null && !onlyStudents.contains(e.getStudentId())) {
                    continue;
                }
                int absent = Math.max(0, total - present.getOrDefault(e.getStudentId(), 0));
                int level = AbsencePolicy.level(c.getAbsenceLimitType(), limit, total, absent);
                apply(c, e.getStudentId(), level, absent);
            }
        } catch (RuntimeException ex) {
            log.warn("Devamsizlik uyarisi hesaplanamadi courseId={}: {}", courseId, ex.toString());
        }
    }

    private void apply(AcCourse c, Long studentId, int level, int absent) {
        Integer raised = tx.execute(s -> level > 0 ? enrollments.raiseWarned(c.getId(), studentId, (short) level) : 0);
        if (raised != null && raised > 0) {
            // bu cagri duzeyi yukseltti: bildirim yalniz bir kez gider
            notifier.absence(c, studentId, level, absent);
        }
        tx.executeWithoutResult(s -> enrollments.lowerWarned(c.getId(), studentId, (short) level));
    }

    /** Sinir metni: COUNT "4", PERCENT "%20". */
    static String limitText(AcCourse c) {
        if (c.getAbsenceLimitType() == null || c.getAbsenceLimitValue() == null) {
            return "";
        }
        return c.getAbsenceLimitType() == AcCourse.LimitType.PERCENT ? "%" + c.getAbsenceLimitValue() : String.valueOf(c.getAbsenceLimitValue());
    }
}
