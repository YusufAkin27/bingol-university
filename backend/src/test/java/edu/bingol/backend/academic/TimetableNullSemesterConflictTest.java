package edu.bingol.backend.academic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.academic.AcademicDtos.CourseRequest;
import edu.bingol.backend.academic.AcademicDtos.SemesterRequest;
import edu.bingol.backend.academic.AcademicDtos.SemesterView;
import edu.bingol.backend.common.ApiException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * FIX-P08 / A07#15: donemsiz (semester_id NULL) ders, guncel donemin ders programinda donemli derslerle BIRLIKTE
 * gorunur; cakisma denetimi de ikisini birlikte kontrol eder.
 */
@SpringBootTest
class TimetableNullSemesterConflictTest {

    static final Instant NOW = Instant.parse("2026-11-02T07:00:00Z");

    @Autowired JdbcTemplate jdbc;

    TimetableService tt;
    long uid;

    @BeforeEach
    void setUp() {
        for (String t : List.of("tt_exam", "tt_session", "tt_course", "tt_semester")) {
            jdbc.update("DELETE FROM " + t);
        }
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'ttn-%'");
        jdbc.update("INSERT INTO app_user (email, password_hash, display_name, email_verified, role, status, language, show_email, "
                + "created_at) VALUES ('ttn-1@bingol.edu.tr', 'x', 'T', TRUE, 'USER', 'ACTIVE', 'tr', FALSE, CURRENT_TIMESTAMP)");
        uid = jdbc.queryForObject("SELECT id FROM app_user WHERE email = 'ttn-1@bingol.edu.tr'", Long.class);
        Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
        AcademicAudience audience = new AcademicAudience(jdbc);
        tt = new TimetableService(jdbc, new ExamService(jdbc, audience, clock), clock);
    }

    @org.junit.jupiter.api.AfterEach
    void cleanup() {
        for (String t : List.of("tt_exam", "tt_session", "tt_course", "tt_semester")) {
            jdbc.update("DELETE FROM " + t);
        }
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'ttn-%'");
    }

    static CourseRequest course(String name, Long semesterId, String start, String end) {
        return new CourseRequest(name, null, null, null, null, semesterId, false, null, 1, start, end, "A1");
    }

    @Test
    void semesterCourseConflictsWithSemesterlessCourseOnCurrentTimetable() {
        tt.createCourse(uid, course("Donemsiz", null, "09:00", "10:00")); // henuz donem yok: semester_id NULL
        SemesterView cur = tt.createSemester(uid, new SemesterRequest("Güz", "2026-09-14", "2027-01-15", true));

        ApiException ex = assertThrows(ApiException.class, () -> tt.createCourse(uid, course("Donemli", cur.id(), "09:30", "10:30")));
        assertEquals("COURSE_CONFLICT", ex.code());
    }

    @Test
    void courseInNonCurrentSemesterIsNotComparedWithSemesterlessOnes() {
        tt.createCourse(uid, course("Donemsiz", null, "09:00", "10:00"));
        tt.createSemester(uid, new SemesterRequest("Güz", "2026-09-14", "2027-01-15", true));
        SemesterView old = tt.createSemester(uid, new SemesterRequest("Eski", "2025-09-14", "2026-01-15", null));
        // guncel olmayan donemin programinda donemsiz dersler gorunmez: cakisma yok
        assertNotNull(tt.createCourse(uid, course("Eski donem", old.id(), "09:30", "10:30")).id());
    }
}
