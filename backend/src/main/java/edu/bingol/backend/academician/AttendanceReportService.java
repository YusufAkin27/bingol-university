package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.AttendanceMatrix;
import edu.bingol.backend.academician.AcademicianDtos.LimitView;
import edu.bingol.backend.academician.AcademicianDtos.SessionRef;
import edu.bingol.backend.academician.AcademicianDtos.StudentRow;
import edu.bingol.backend.academician.AttendanceMath.Result;
import edu.bingol.backend.academician.AttendanceStats.CourseStats;
import edu.bingol.backend.academician.StudentDirectory.Person;
import edu.bingol.backend.admin.Csv;
import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Devamsizlik matrisi ve CSV. Sayim kurallari TEK yerde ({@link AttendanceMath}): canli, "sayilmasin" denen, ogrencinin derse
 * eklenmesinden onceki ve o ogrenci icin izinli oturumlar ogrencinin sayilarina girmez; matriste yine de sutun/isaret olarak
 * gorunur (canli sutunda "yok" geciciidir: {@code live=true}).
 */
@Service
public class AttendanceReportService {

    private final AcademicianGuard guard;
    private final AcCourseRepository courses;
    private final AcSessionRepository sessions;
    private final AttendanceStats stats;
    private final StudentDirectory directory;
    private final SessionFinalizer finalizer;
    private final Clock clock;

    public AttendanceReportService(AcademicianGuard guard, AcCourseRepository courses, AcSessionRepository sessions,
                                   AttendanceStats stats, StudentDirectory directory, SessionFinalizer finalizer, Clock clock) {
        this.guard = guard;
        this.courses = courses;
        this.sessions = sessions;
        this.stats = stats;
        this.directory = directory;
        this.finalizer = finalizer;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public AttendanceMatrix matrix(Long userId, Long courseId) {
        return build(guard.ownCourse(userId, courseId));
    }

    /** Yonetici okumasi: sahiplik aranmaz; users.pii olmayan profillerde ogrenci numarasi (e-posta yerel kismi) maskelenir. */
    @Transactional(readOnly = true)
    public AttendanceMatrix matrixForAdmin(Long courseId) {
        AttendanceMatrix m = build(courses.findById(courseId).orElseThrow(AcErrors::courseNotFound));
        if (PermissionAwareMasking.canSeePii()) {
            return m;
        }
        List<StudentRow> masked = m.students().stream().map(r -> new StudentRow(r.studentId(), r.displayName(),
                PermissionAwareMasking.opaque(r.studentNo()), r.marks(), r.sessionCount(), r.absentCount(), r.excusedCount(),
                r.atRisk(), r.overLimit())).toList();
        return new AttendanceMatrix(m.sessions(), masked, m.limit());
    }

    @Transactional(readOnly = true)
    public String csv(Long userId, Long courseId) {
        return toCsv(build(guard.ownCourse(userId, courseId)));
    }

    AttendanceMatrix build(AcCourse c) {
        Instant now = clock.instant();
        // suresi dolmus ama kapatilmamis oturumlar once kesinlestirilir (ilk gozlem)
        finalizer.observeExpired(sessions.ofCourseOldestFirst(c.getId(), PageRequest.of(0, AttendanceStats.MAX_SESSIONS)), now);
        CourseStats cs = stats.forCourse(c, null, now);
        Map<Long, Person> people = directory.labels(cs.enrolled().stream().map(AcEnrollment::getStudentId).toList());
        List<StudentRow> rows = new ArrayList<>();
        for (AcEnrollment e : cs.enrolled()) {
            Person p = people.get(e.getStudentId());
            Result r = cs.byStudent().get(e.getStudentId());
            rows.add(new StudentRow(e.getStudentId(), p == null ? null : p.displayName(), p == null ? null : p.studentNo(), r.marks(),
                    r.sessionCount(), r.absent(), r.excused(), r.atRisk(), r.overLimit()));
        }
        rows.sort(Comparator.comparing(StudentRow::displayName, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER)));
        List<SessionRef> refs = cs.sessions().stream()
                .map(s -> new SessionRef(s.getId(), s.getLessonDate(), s.isLive(now), s.isCounted())).toList();
        return new AttendanceMatrix(refs, rows, CourseService.limitOf(c));
    }

    static String markText(String mark) {
        return switch (mark) {
            case "PRESENT_QR" -> "Var (QR)";
            case "PRESENT_MANUAL" -> "Var (elle)";
            case "REVOKED" -> "Silindi";
            case "EXCUSED" -> "İzinli";
            case "NOT_ENROLLED_YET" -> "Kayıtlı değildi";
            default -> "Yok";
        };
    }

    static String toCsv(AttendanceMatrix m) {
        StringBuilder sb = new StringBuilder(Csv.BOM);
        List<Object> head = new ArrayList<>(List.of("Öğrenci No", "Ad Soyad"));
        m.sessions().forEach(s -> head.add(s.lessonDate().toString() + (s.counted() ? "" : " (sayılmıyor)")));
        head.add("Devamsızlık");
        head.add("Durum");
        sb.append(Csv.row(head));
        LimitView lim = m.limit();
        for (StudentRow r : m.students()) {
            List<Object> cells = new ArrayList<>();
            cells.add(r.studentNo());
            cells.add(r.displayName());
            m.sessions().forEach(s -> cells.add(markText(r.marks().getOrDefault(String.valueOf(s.id()), "ABSENT"))));
            cells.add(r.absentCount());
            cells.add(r.overLimit() ? (reachedExactly(lim, r) ? "Sınıra ulaştı" : "Sınır aşıldı") : r.atRisk() ? "Riskli" : "");
            sb.append(Csv.row(cells));
        }
        return sb.toString();
    }

    /** Devamsizlik tam sinira esitse "ulasti", ustundeyse "asildi". */
    private static boolean reachedExactly(LimitView lim, StudentRow r) {
        if (lim == null || lim.value() == null) {
            return false;
        }
        if (lim.allowedAbsences() != null) {
            return r.absentCount() == lim.allowedAbsences();
        }
        return (long) r.absentCount() * 100 == (long) lim.value() * r.sessionCount(); // PERCENT, planlanan yok
    }
}
