package edu.bingol.backend.academic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.academic.AcademicDtos.OfficialExamView;
import edu.bingol.backend.academic.AcademicDtos.OfficialExamsView;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * FIX-P08 / A07#1: resmi sinav listesi SQL'de suzulur. 500'den cok gecmis sinav olsa bile yeni (yayinli) sinavlar
 * gorunur; gecmis (30 gunden eski) kayitlar listeden duser (K21) ve kapsam suzgeci veritabaninda isler.
 */
@SpringBootTest
class ExamOfficialAllReturnsUpcomingTest {

    static final Instant NOW = Instant.parse("2026-11-02T07:00:00Z");

    @Autowired JdbcTemplate jdbc;

    ExamService exams;
    long uid;
    long uidLaw;

    @BeforeEach
    void setUp() {
        jdbc.update("DELETE FROM exam_schedule");
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'exo-%'");
        uid = user("exo-1@bingol.edu.tr", "Bilgisayar Mühendisliği", "Mühendislik Fakültesi", "2");
        uidLaw = user("exo-2@bingol.edu.tr", "Hukuk", "Hukuk Fakültesi", "1");
        exams = new ExamService(jdbc, new AcademicAudience(jdbc), Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @org.junit.jupiter.api.AfterEach
    void cleanup() {
        jdbc.update("DELETE FROM exam_schedule");
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'exo-%'");
    }

    long user(String email, String dept, String faculty, String grade) {
        jdbc.update("INSERT INTO app_user (email, password_hash, display_name, email_verified, role, status, department, faculty, "
                + "grade, language, show_email, created_at) VALUES (?, 'x', 'T', TRUE, 'USER', 'ACTIVE', ?, ?, ?, 'tr', FALSE, CURRENT_TIMESTAMP)",
                email, dept, faculty, grade);
        return jdbc.queryForObject("SELECT id FROM app_user WHERE email = ?", Long.class, email);
    }

    void schedule(String title, Instant starts, String dept, String faculty, String grade, boolean published) {
        jdbc.update("INSERT INTO exam_schedule (title, type, term, department, faculty, grade, starts_at, published) "
                + "VALUES (?, 'FINAL', '2026 Güz', ?, ?, ?, ?, ?)", title, dept, faculty, grade, Timestamp.from(starts), published);
    }

    @Test
    void sixHundredOldExamsDoNotHideTheNewOnes() {
        for (int i = 0; i < 600; i++) {
            schedule("Eski " + i, NOW.minus(40 + i % 300, ChronoUnit.DAYS), null, null, null, true);
        }
        for (int i = 0; i < 10; i++) {
            schedule("Yeni " + i, NOW.plus(1 + i, ChronoUnit.DAYS), null, null, null, true);
        }
        OfficialExamsView all = exams.official(uid, true);
        assertEquals(10, all.items().size(), "yalniz yaklasan/guncel sinavlar");
        assertTrue(all.items().stream().allMatch(e -> e.title().startsWith("Yeni")));
        assertEquals("Yeni 0", all.items().get(0).title(), "tarihe gore artan");
        assertEquals(10, exams.official(uid, false).items().size());
    }

    @Test
    void recentPastWithinThirtyDaysStaysAndAtMost500Returned() {
        schedule("Gecen hafta", NOW.minus(7, ChronoUnit.DAYS), null, null, null, true);
        schedule("Cok eski", NOW.minus(45, ChronoUnit.DAYS), null, null, null, true);
        for (int i = 0; i < 520; i++) {
            schedule("Gelecek " + i, NOW.plus(1 + i, ChronoUnit.HOURS), null, null, null, true);
        }
        List<OfficialExamView> items = exams.official(uid, true).items();
        assertEquals(500, items.size());
        assertEquals("Gecen hafta", items.get(0).title());
    }

    @Test
    void scopeFilterRunsInSqlAndStaysConsistentWithAudienceMatch() {
        schedule("Genel", NOW.plus(1, ChronoUnit.DAYS), null, null, null, true);
        schedule("BM", NOW.plus(2, ChronoUnit.DAYS), "bilgisayar mühendisliği", null, "2", true);
        schedule("BM3", NOW.plus(3, ChronoUnit.DAYS), "Bilgisayar Mühendisliği", null, "3", true);
        schedule("Taslak", NOW.plus(4, ChronoUnit.DAYS), null, null, null, false);
        schedule("Hukuk", NOW.plus(5, ChronoUnit.DAYS), "Hukuk", "Hukuk Fakültesi", "1", true);
        assertEquals(List.of("Genel", "BM"), exams.official(uid, false).items().stream().map(OfficialExamView::title).toList());
        assertEquals(List.of("Genel", "Hukuk"), exams.official(uidLaw, false).items().stream().map(OfficialExamView::title).toList());
        assertEquals(4, exams.official(uid, true).items().size());
    }

    @Test
    void endedExamKeepsBeingListedUntilWindowEndsByEndsAt() {
        // baslangici 40 gun once ama bitisi 10 gun once: COALESCE(ends_at, starts_at) penceresi icinde
        jdbc.update("INSERT INTO exam_schedule (title, type, term, starts_at, ends_at, published) VALUES "
                + "('Uzun', 'FINAL', '2026 Güz', ?, ?, TRUE)", Timestamp.from(NOW.minus(40, ChronoUnit.DAYS)),
                Timestamp.from(NOW.minus(10, ChronoUnit.DAYS)));
        assertEquals(1, exams.official(uid, true).items().size());
    }
}
