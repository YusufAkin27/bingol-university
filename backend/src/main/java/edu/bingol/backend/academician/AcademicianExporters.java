package edu.bingol.backend.academician;

import edu.bingol.backend.export.DataExporter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.domain.PageRequest;

/**
 * KVKK "verilerimi indir": "academician" (kendi akademisyen profili + sahibi oldugu dersler) ve "courseAttendance"
 * (ogrencinin kendi ders kayitlari ve yoklama satirlari). Baskasinin verisi (diger ogrenciler, ders arkadaslari) ASLA.
 */
@Configuration
public class AcademicianExporters {

    private static final int MAX = 500;

    private final AcademicianRepository academicians;
    private final AcCourseRepository courses;
    private final AcEnrollmentRepository enrollments;
    private final AcAttendanceRepository attendance;
    private final AcSessionRepository sessions;

    public AcademicianExporters(AcademicianRepository academicians, AcCourseRepository courses,
                                AcEnrollmentRepository enrollments, AcAttendanceRepository attendance,
                                AcSessionRepository sessions) {
        this.academicians = academicians;
        this.courses = courses;
        this.enrollments = enrollments;
        this.attendance = attendance;
        this.sessions = sessions;
    }

    @Bean
    DataExporter academicianExporter() {
        return DataExporter.of("academician", uid -> {
            Map<String, Object> out = new LinkedHashMap<>();
            Academician a = academicians.findById(uid).orElse(null);
            if (a == null) {
                return out;
            }
            out.put("title", a.getTitle());
            out.put("firstName", a.getFirstName());
            out.put("lastName", a.getLastName());
            out.put("unit", a.getUnit());
            out.put("status", a.getStatus().name());
            out.put("approvalMode", a.getApprovalMode() == null ? null : a.getApprovalMode().name());
            out.put("createdAt", a.getCreatedAt().toString());
            List<Map<String, Object>> cs = new ArrayList<>();
            for (AcCourse c : courses.ofOwner(uid, PageRequest.of(0, MAX))) {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("name", c.getName());
                m.put("code", c.getCode());
                m.put("term", c.getTerm());
                m.put("department", c.getDepartment());
                m.put("status", c.getStatus().name());
                cs.add(m);
            }
            out.put("courses", cs);
            return out;
        });
    }

    @Bean
    DataExporter courseAttendanceExporter() {
        return DataExporter.of("courseAttendance", uid -> {
            List<Long> courseIds = enrollments.courseIdsOf(uid, PageRequest.of(0, MAX));
            Map<Long, String> names = courseIds.isEmpty() ? Map.of()
                    : courses.byIds(courseIds).stream().collect(Collectors.toMap(AcCourse::getId, AcCourse::getName));
            List<AcAttendance> rows = attendance.ofStudent(uid, PageRequest.of(0, EnrollmentService.MAX_ENROLLED));
            Map<Long, AcSession> sess = new HashMap<>();
            sessions.findAllById(rows.stream().map(AcAttendance::getSessionId).distinct().toList())
                    .forEach(s -> sess.put(s.getId(), s));
            List<Map<String, Object>> recs = new ArrayList<>();
            for (AcAttendance a : rows) {
                AcSession s = sess.get(a.getSessionId());
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("course", s == null ? null : names.get(s.getCourseId()));
                m.put("lessonDate", s == null ? null : s.getLessonDate().toString());
                m.put("method", a.getMethod().name());
                m.put("markedAt", a.getMarkedAt().toString());
                m.put("revoked", a.isRevoked());
                recs.add(m);
            }
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("enrolledCourses", new ArrayList<>(names.values()));
            out.put("records", recs);
            return out;
        });
    }
}
