package edu.bingol.backend.academic;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.bingol.backend.dbmaint.ChunkedDeleter;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;

/** FIX-P08 / A07#9 (K23): eski donem/duyuru/sinav kayitlari parcali silinir; yeni olanlara dokunulmaz. */
@SpringBootTest
class AcademicRetentionJobTest {

    static final Instant NOW = Instant.parse("2026-11-02T07:00:00Z");

    @Autowired JdbcTemplate jdbc;

    AcademicRetentionJob job;
    long uid;

    @BeforeEach
    void setUp() {
        for (String t : new String[] {"academic_event",
                "tt_exam", "tt_session", "tt_course", "tt_semester"}) {
            jdbc.update("DELETE FROM " + t);
        }
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'ret-%'");
        jdbc.update("INSERT INTO app_user (email, password_hash, display_name, email_verified, role, status, language, show_email, "
                + "created_at) VALUES ('ret-1@bingol.edu.tr', 'x', 'T', TRUE, 'USER', 'ACTIVE', 'tr', FALSE, CURRENT_TIMESTAMP)");
        uid = jdbc.queryForObject("SELECT id FROM app_user WHERE email = 'ret-1@bingol.edu.tr'", Long.class);
        ChunkedDeleter deleter = new ChunkedDeleter(new NamedParameterJdbcTemplate(jdbc), new SimpleMeterRegistry(), 100, 0, 20);
        job = new AcademicRetentionJob(deleter, null, Clock.fixed(NOW, ZoneOffset.UTC), 365);
    }

    @org.junit.jupiter.api.AfterEach
    void cleanup() {
        for (String t : new String[] {"academic_event",
                "tt_exam", "tt_session", "tt_course", "tt_semester"}) {
            jdbc.update("DELETE FROM " + t);
        }
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'ret-%'");
    }

    static Timestamp ago(int days) {
        return Timestamp.from(NOW.minus(days, ChronoUnit.DAYS));
    }

    int count(String table) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM " + table, Integer.class);
    }

    @Test
    void oldEventsAndPersonalExamsAreDeleted() {
        jdbc.update("INSERT INTO academic_event (kind, title, starts_at, published) VALUES ('OZEL', 'eski', ?, TRUE)", ago(500));
        jdbc.update("INSERT INTO academic_event (kind, title, starts_at, published) VALUES ('OZEL', 'yeni', ?, TRUE)", ago(5));
        jdbc.update("INSERT INTO tt_exam (user_id, title, type, starts_at) VALUES (?, 'eski', 'VIZE', ?)", uid, ago(500));
        jdbc.update("INSERT INTO tt_exam (user_id, title, type, starts_at) VALUES (?, 'yeni', 'VIZE', ?)", uid, ago(3));

        job.runAll();

        assertEquals(1, count("academic_event"));
        assertEquals(1, count("tt_exam"));
    }

    @Test
    void oldSemestersWithCoursesAndSessionsAreDeletedCurrentKept() {
        jdbc.update("INSERT INTO tt_semester (user_id, name, start_date, end_date, is_current) VALUES (?, 'eski', DATE '2024-09-01', DATE '2025-01-15', FALSE)", uid);
        jdbc.update("INSERT INTO tt_semester (user_id, name, start_date, end_date, is_current) VALUES (?, 'guncel', DATE '2026-09-14', DATE '2027-01-15', TRUE)", uid);
        long oldSem = jdbc.queryForObject("SELECT id FROM tt_semester WHERE name = 'eski'", Long.class);
        long curSem = jdbc.queryForObject("SELECT id FROM tt_semester WHERE name = 'guncel'", Long.class);
        for (long sem : new long[] {oldSem, curSem}) {
            jdbc.update("INSERT INTO tt_course (user_id, semester_id, name, color) VALUES (?, ?, 'ders', 'blue')", uid, sem);
        }
        jdbc.update("INSERT INTO tt_session (course_id, day_of_week, start_time, end_time) "
                + "SELECT id, 1, TIME '09:00:00', TIME '10:00:00' FROM tt_course");

        job.runAll();

        assertEquals(1, count("tt_semester"));
        assertEquals(1, count("tt_course"));
        assertEquals(1, count("tt_session"));
    }

    @Test
    void zeroDisablesGroups() {
        jdbc.update("INSERT INTO academic_event (kind, title, starts_at, published) VALUES ('OZEL', 'eski', ?, TRUE)", ago(500));
        ChunkedDeleter deleter = new ChunkedDeleter(new NamedParameterJdbcTemplate(jdbc), new SimpleMeterRegistry(), 100, 0, 20);
        new AcademicRetentionJob(deleter, null, Clock.fixed(NOW, ZoneOffset.UTC), 0).runAll();
        assertEquals(1, count("academic_event"));
    }
}
