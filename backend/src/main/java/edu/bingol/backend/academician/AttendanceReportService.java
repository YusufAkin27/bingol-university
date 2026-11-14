package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AcademicianDtos.AttendanceMatrix;
import edu.bingol.backend.academician.AcademicianDtos.LimitView;
import edu.bingol.backend.academician.AcademicianDtos.SessionRef;
import edu.bingol.backend.academician.AcademicianDtos.StudentRow;
import edu.bingol.backend.academician.StudentDirectory.Person;
import edu.bingol.backend.admin.Csv;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Devamsizlik matrisi ve CSV. "Yok" = derse kayitli ve o oturumda yoklama satiri olmayan. Sinir degerlendirmesi:
 * COUNT icin devamsizlik &gt; deger, PERCENT icin devamsizlik/oturum sayisi &gt; yuzde => overLimit; atRisk = henuz asilmamis
 * ama bir devamsizlik daha (yeni bir oturumla) siniri asacak ve ogrencinin en az bir devamsizligi var.
 */
@Service
public class AttendanceReportService {

    static final int MAX_SESSIONS = 400;
    static final int MAX_PAIRS = 400_000;

    private final AcademicianGuard guard;
    private final AcCourseRepository courses;
    private final AcSessionRepository sessions;
    private final AcEnrollmentRepository enrollments;
    private final AcAttendanceRepository attendance;
    private final StudentDirectory directory;
    private final SessionFinalizer finalizer;
    private final java.time.Clock clock;

    public AttendanceReportService(AcademicianGuard guard, AcCourseRepository courses, AcSessionRepository sessions,
                                   AcEnrollmentRepository enrollments, AcAttendanceRepository attendance,
                                   StudentDirectory directory, SessionFinalizer finalizer, java.time.Clock clock) {
        this.guard = guard;
        this.courses = courses;
        this.sessions = sessions;
        this.enrollments = enrollments;
        this.attendance = attendance;
        this.directory = directory;
        this.finalizer = finalizer;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public AttendanceMatrix matrix(Long userId, Long courseId) {
        return build(guard.ownCourse(userId, courseId));
    }

    /** Yonetici okumasi: sahiplik aranmaz. */
    @Transactional(readOnly = true)
    public AttendanceMatrix matrixForAdmin(Long courseId) {
        return build(courses.findById(courseId).orElseThrow(AcErrors::courseNotFound));
    }

    @Transactional(readOnly = true)
    public String csv(Long userId, Long courseId) {
        return toCsv(build(guard.ownCourse(userId, courseId)));
    }

    AttendanceMatrix build(AcCourse c) {
        List<AcSession> ss = sessions.ofCourseOldestFirst(c.getId(), PageRequest.of(0, MAX_SESSIONS));
        if (finalizer != null) {
            finalizer.observeExpired(ss, clock.instant());
        }
        List<Long> sessionIds = ss.stream().map(AcSession::getId).toList();
        List<AcEnrollment> enrolled = enrollments.ofCourse(c.getId(), PageRequest.of(0, EnrollmentService.MAX_ENROLLED));
        Map<Long, Person> people = directory.labels(enrolled.stream().map(AcEnrollment::getStudentId).toList());
        Map<Long, Map<String, String>> marksBy = new HashMap<>();
        if (!sessionIds.isEmpty()) {
            Set<Long> enrolledIds = new HashSet<>(enrolled.stream().map(AcEnrollment::getStudentId).toList());
            for (Object[] row : attendance.pairsOf(sessionIds, PageRequest.of(0, MAX_PAIRS))) {
                Long stu = (Long) row[1];
                if (enrolledIds.contains(stu)) {
                    String mark = row[3] != null ? "REVOKED" : row[2] == AcAttendance.Method.QR ? "PRESENT_QR" : "PRESENT_MANUAL";
                    marksBy.computeIfAbsent(stu, k -> new HashMap<>()).put(String.valueOf(row[0]), mark);
                }
            }
        }
        int total = ss.size();
        List<StudentRow> rows = new ArrayList<>();
        for (AcEnrollment e : enrolled) {
            Person p = people.get(e.getStudentId());
            Map<String, String> have = marksBy.getOrDefault(e.getStudentId(), Map.of());
            Map<String, String> marks = new java.util.LinkedHashMap<>();
            int absent = 0;
            for (AcSession s : ss) {
                String m = have.getOrDefault(String.valueOf(s.getId()), "ABSENT");
                marks.put(String.valueOf(s.getId()), m);
                if (m.equals("ABSENT") || m.equals("REVOKED")) {
                    absent++;
                }
            }
            AbsencePolicy.Standing st = standing(c.getAbsenceLimitType(), c.getAbsenceLimitValue() == null ? null : c.getAbsenceLimitValue().intValue(),
                    total, absent);
            rows.add(new StudentRow(e.getStudentId(), p == null ? null : p.displayName(), p == null ? null : p.studentNo(),
                    marks, absent, st.atRisk(), st.overLimit()));
        }
        rows.sort(Comparator.comparing(StudentRow::displayName, Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER)));
        return new AttendanceMatrix(ss.stream().map(s -> new SessionRef(s.getId(), s.getLessonDate())).toList(), rows,
                CourseService.limitOf(c));
    }

    static AbsencePolicy.Standing standing(AcCourse.LimitType type, Integer value, int total, int absent) {
        return AbsencePolicy.standing(type, value, total, absent);
    }

    static String toCsv(AttendanceMatrix m) {
        StringBuilder sb = new StringBuilder(Csv.BOM);
        List<Object> head = new ArrayList<>(List.of("Öğrenci No", "Ad Soyad"));
        m.sessions().forEach(s -> head.add(s.lessonDate().toString()));
        head.add("Devamsızlık");
        head.add("Durum");
        sb.append(Csv.row(head));
        for (StudentRow r : m.students()) {
            List<Object> cells = new ArrayList<>();
            cells.add(r.studentNo());
            cells.add(r.displayName());
            m.sessions().forEach(s -> cells.add(switch (r.marks().getOrDefault(String.valueOf(s.id()), "ABSENT")) {
                case "PRESENT_QR" -> "Var (QR)";
                case "PRESENT_MANUAL" -> "Var (elle)";
                case "REVOKED" -> "Silindi";
                default -> "Yok";
            }));
            cells.add(r.absentCount());
            cells.add(r.overLimit() ? "Sınır aşıldı" : r.atRisk() ? "Riskli" : "");
            sb.append(Csv.row(cells));
        }
        return sb.toString();
    }

    static LimitView noLimit() {
        return new LimitView(null, null);
    }
}
