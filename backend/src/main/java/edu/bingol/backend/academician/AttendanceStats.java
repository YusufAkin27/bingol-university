package edu.bingol.backend.academician;

import edu.bingol.backend.academician.AttendanceMath.Rec;
import edu.bingol.backend.academician.AttendanceMath.Result;
import edu.bingol.backend.academician.AttendanceMath.Sess;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;

/** {@link AttendanceMath} icin veri yukleyici: matris, uyari ve Derslerim ayni sayimi buradan alir. */
@Component
public class AttendanceStats {

    static final int MAX_SESSIONS = 400;
    static final int MAX_PAIRS = 400_000;

    /** sessions: matris sutunlari (eski -> yeni); byStudent: yalniz SU AN kayitli ogrenciler. */
    record CourseStats(List<AcSession> sessions, List<AcEnrollment> enrolled, Map<Long, Result> byStudent) {}

    private final AcSessionRepository sessions;
    private final AcEnrollmentRepository enrollments;
    private final AcAttendanceRepository attendance;
    private final AcademicianProperties props;

    public AttendanceStats(AcSessionRepository sessions, AcEnrollmentRepository enrollments, AcAttendanceRepository attendance,
                           AcademicianProperties props) {
        this.sessions = sessions;
        this.enrollments = enrollments;
        this.attendance = attendance;
        this.props = props;
    }

    static Sess sess(AcSession s, Instant now) {
        return new Sess(s.getId(), s.getOpenedAt(), s.isLive(now), s.isCounted());
    }

    private static Rec rec(Object[] row) {
        return new Rec((AcAttendance.Method) row[2], row[3] != null, Boolean.TRUE.equals(row[4]));
    }

    /** {@code only} null ise tum kayitli ogrenciler. */
    CourseStats forCourse(AcCourse c, Collection<Long> only, Instant now) {
        List<AcSession> ss = sessions.ofCourseOldestFirst(c.getId(), PageRequest.of(0, MAX_SESSIONS));
        List<AcEnrollment> enrolled = enrollments.ofCourse(c.getId(), PageRequest.of(0, EnrollmentService.MAX_ENROLLED));
        List<Long> sessionIds = ss.stream().map(AcSession::getId).toList();
        Map<Long, Map<Long, Rec>> recs = new HashMap<>();
        if (!sessionIds.isEmpty()) {
            List<Object[]> rows = only == null
                    ? attendance.pairsOf(sessionIds, PageRequest.of(0, MAX_PAIRS))
                    : attendance.pairsOfStudents(sessionIds, only, PageRequest.of(0, MAX_PAIRS));
            for (Object[] row : rows) {
                recs.computeIfAbsent((Long) row[1], k -> new HashMap<>()).put((Long) row[0], rec(row));
            }
        }
        List<Sess> view = new ArrayList<>();
        ss.forEach(s -> view.add(sess(s, now)));
        Integer value = c.getAbsenceLimitValue() == null ? null : c.getAbsenceLimitValue().intValue();
        Integer planned = c.getPlannedSessions() == null ? null : c.getPlannedSessions().intValue();
        Map<Long, Result> out = new LinkedHashMap<>();
        for (AcEnrollment e : enrolled) {
            if (only != null && !only.contains(e.getStudentId())) {
                continue;
            }
            out.put(e.getStudentId(), AttendanceMath.compute(view, e.getAddedAt(), recs.getOrDefault(e.getStudentId(), Map.of()),
                    c.getAbsenceLimitType(), value, planned, props.percentMinSessions()));
        }
        return new CourseStats(ss, enrolled, out);
    }

    /** Ogrencinin her dersi icin sayim (courseId -> sonuc). */
    Map<Long, Result> forStudent(Long studentId, Collection<AcCourse> courses, Instant now) {
        Map<Long, Result> out = new HashMap<>();
        if (courses.isEmpty()) {
            return out;
        }
        List<Long> ids = courses.stream().map(AcCourse::getId).toList();
        Map<Long, Instant> addedAt = new HashMap<>();
        enrollments.ofStudent(studentId, PageRequest.of(0, StudentCourseService.MAX_COURSES))
                .forEach(e -> addedAt.put(e.getCourseId(), e.getAddedAt()));
        Map<Long, List<AcSession>> byCourse = new HashMap<>();
        for (AcSession s : sessions.ofCourses(ids, PageRequest.of(0, MAX_SESSIONS * StudentCourseService.MAX_COURSES))) {
            byCourse.computeIfAbsent(s.getCourseId(), k -> new ArrayList<>()).add(s);
        }
        Map<Long, Rec> mine = new HashMap<>();
        for (AcAttendance a : attendance.ofStudent(studentId, PageRequest.of(0, EnrollmentService.MAX_ENROLLED))) {
            mine.put(a.getSessionId(), new Rec(a.getMethod(), a.isRevoked(), a.isExcused()));
        }
        for (AcCourse c : courses) {
            List<Sess> view = new ArrayList<>();
            Map<Long, Rec> recs = new HashMap<>();
            for (AcSession s : byCourse.getOrDefault(c.getId(), List.of())) {
                view.add(sess(s, now));
                Rec r = mine.get(s.getId());
                if (r != null) {
                    recs.put(s.getId(), r);
                }
            }
            Integer value = c.getAbsenceLimitValue() == null ? null : c.getAbsenceLimitValue().intValue();
            Integer planned = c.getPlannedSessions() == null ? null : c.getPlannedSessions().intValue();
            out.put(c.getId(), AttendanceMath.compute(view, addedAt.get(c.getId()), recs, c.getAbsenceLimitType(), value, planned,
                    props.percentMinSessions()));
        }
        return out;
    }
}
