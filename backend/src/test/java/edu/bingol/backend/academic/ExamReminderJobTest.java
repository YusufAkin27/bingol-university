package edu.bingol.backend.academic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.academic.AcademicDtos.ExamRequest;
import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationType;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.invocation.Invocation;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Sinav hatirlatma gorevi (sinavdan 2 sa once push): pencere sinirlari, tekrar onleme, saat degisince yeniden,
 * silinen sinav, hata yalitimi ve parca isleme. H2 uzerinde duz SQL (PostgreSQL ile ortak alt kume); bildirim servisi sahte.
 * Saat sabit: 2026-11-02 07:00Z (= 10:00 Istanbul).
 */
@SpringBootTest
class ExamReminderJobTest {

    static final Instant NOW = Instant.parse("2026-11-02T07:00:00Z");

    @Autowired JdbcTemplate jdbc;

    Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
    NotificationService notifications;
    ExamReminderJob job;
    ExamService exams;
    long uid;
    long uid2;

    @BeforeEach
    void setUp() {
        jdbc.update("DELETE FROM tt_exam");
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'exr-%'");
        uid = user("exr-1@bingol.edu.tr");
        uid2 = user("exr-2@bingol.edu.tr");
        notifications = mock(NotificationService.class);
        job = new ExamReminderJob(jdbc, notifications, null, clock);
        exams = new ExamService(jdbc, new AcademicAudience(jdbc), clock);
    }

    long user(String email) {
        jdbc.update("INSERT INTO app_user (email, password_hash, display_name, email_verified, role, status, language, show_email, "
                + "created_at) VALUES (?, 'x', 'T', TRUE, 'USER', 'ACTIVE', 'tr', FALSE, CURRENT_TIMESTAMP)", email);
        return jdbc.queryForObject("SELECT id FROM app_user WHERE email = ?", Long.class, email);
    }

    long exam(long userId, String title, Instant startsAt, String room) {
        jdbc.update("INSERT INTO tt_exam (user_id, title, type, starts_at, room) VALUES (?, ?, 'VIZE', ?, ?)", userId, title,
                Timestamp.from(startsAt), room);
        return jdbc.queryForObject("SELECT MAX(id) FROM tt_exam", Long.class);
    }

    /** sendTemplate cagrilari: [kullanici, sablon, veri, collapseKey, baslik, saat, (salon)]. */
    List<Object[]> sent() {
        List<Object[]> out = new ArrayList<>();
        for (Invocation inv : Mockito.mockingDetails(notifications).getInvocations()) {
            if (inv.getMethod().getName().equals("sendTemplate")) {
                out.add(inv.getArguments());
            }
        }
        return out;
    }

    List<String> sentTitles() {
        return sent().stream().map(a -> (String) a[4]).sorted().toList();
    }

    static Instant in(Duration d) {
        return NOW.plus(d);
    }

    // ---------------- pencere ----------------

    @Test
    void windowBoundsAreHonoured() {
        exam(uid, "in-1h59", in(Duration.ofMinutes(119)), null);
        exam(uid, "in-2h00-exact", in(Duration.ofHours(2)), null);
        exam(uid, "out-2h01", in(Duration.ofMinutes(121)), null);
        exam(uid, "out-1day", in(Duration.ofDays(1)), null);
        exam(uid, "late-catch-45m", in(Duration.ofMinutes(45)), null); // gorev kacirildiysa gec de olsa
        exam(uid, "late-edge-30m", in(Duration.ofMinutes(30)), null);
        exam(uid, "out-29m", in(Duration.ofMinutes(29)), null);
        exam(uid, "out-started", in(Duration.ofMinutes(-10)), null);
        exam(uid, "out-past-day", in(Duration.ofDays(-1)), null);

        assertEquals(4, job.run(NOW));
        assertEquals(List.of("in-1h59", "in-2h00-exact", "late-catch-45m", "late-edge-30m"), sentTitles());
    }

    @Test
    void messageArgsCarryTitleIstanbulTimeAndOptionalRoom() {
        long withRoom = exam(uid, "Veri Yapıları", Instant.parse("2026-11-02T08:30:00Z"), "A-12"); // 11:30 Istanbul
        exam(uid2, "Fizik", Instant.parse("2026-11-02T08:45:00Z"), null);
        assertEquals(2, job.run(NOW));

        Object[] r = sent().stream().filter(a -> a[0].equals(uid)).findFirst().orElseThrow();
        assertEquals(ExamReminderJob.TEMPLATE_ROOM, r[1]);
        assertEquals("Veri Yapıları", r[4]);
        assertEquals("11:30", r[5]);
        assertEquals("A-12", r[6]);
        @SuppressWarnings("unchecked")
        Map<String, String> data = (Map<String, String>) r[2];
        assertEquals("EXAM", data.get("target"));
        assertEquals(String.valueOf(withRoom), data.get("value"));
        assertEquals(String.valueOf(withRoom), data.get("examId"));
        assertTrue(((String) r[3]).startsWith("exam:" + withRoom + ":"));

        Object[] n = sent().stream().filter(a -> a[0].equals(uid2)).findFirst().orElseThrow();
        assertEquals(ExamReminderJob.TEMPLATE, n[1]);
        assertEquals(6, n.length); // oda yok: kullanici, sablon, veri, anahtar, baslik, saat
        assertEquals("11:45", n[5]);
        assertEquals(NotificationType.ANNOUNCEMENT, ExamReminderJob.TEMPLATE.type());
        assertEquals(NotificationSubtype.EXAM_REMINDER, ExamReminderJob.TEMPLATE.subtype());
    }

    // ---------------- tekrar onleme ----------------

    @Test
    void sameExamIsNotSentTwice() {
        exam(uid, "Vize", in(Duration.ofMinutes(100)), null);
        assertEquals(1, job.run(NOW));
        assertEquals(0, job.run(NOW));
        assertEquals(0, job.run(NOW.plusSeconds(60)));
        assertEquals(1, sent().size());
    }

    @Test
    void rescheduledExamIsRemindedAgain() {
        long id = exam(uid, "Vize", in(Duration.ofMinutes(100)), null);
        assertEquals(1, job.run(NOW));
        // Kullanici sinav saatini erteledi (hala 2 saat icinde, ama baska saat): yeniden hatirlatilir.
        jdbc.update("UPDATE tt_exam SET starts_at = ? WHERE id = ?", Timestamp.from(in(Duration.ofMinutes(110))), id);
        assertEquals(1, job.run(NOW));
        assertEquals(2, sent().size());
        assertEquals(0, job.run(NOW));
    }

    @Test
    void examMovedFarAwayIsRemindedWhenItsNewTimeComes() {
        long id = exam(uid, "Final", in(Duration.ofMinutes(100)), null);
        assertEquals(1, job.run(NOW));
        Instant newStart = NOW.plus(Duration.ofDays(3));
        jdbc.update("UPDATE tt_exam SET starts_at = ? WHERE id = ?", Timestamp.from(newStart), id);
        assertEquals(0, job.run(NOW)); // henuz pencere disi
        Instant later = newStart.minus(Duration.ofMinutes(110));
        ExamReminderJob laterJob = new ExamReminderJob(jdbc, notifications, null, Clock.fixed(later, ZoneOffset.UTC));
        assertEquals(1, laterJob.run(later));
        assertEquals(2, sent().size());
    }

    @Test
    void deletedExamIsNotSent() {
        long a = exam(uid, "Silinecek", in(Duration.ofMinutes(100)), null);
        exam(uid, "Kalacak", in(Duration.ofMinutes(100)), null);
        jdbc.update("DELETE FROM tt_exam WHERE id = ?", a);
        assertEquals(1, job.run(NOW));
        assertEquals(List.of("Kalacak"), sentTitles());
    }

    // ---------------- ExamService ile etkilesim ----------------

    @Test
    void examCreatedInsideTheWindowDoesNotFirePushImmediately() {
        exams.create(uid, new ExamRequest(null, "Yakin", "VIZE", "2026-11-02T08:30:00Z", null, null, null));
        assertEquals(0, job.run(NOW));
        exams.create(uid, new ExamRequest(null, "Uzak", "VIZE", "2026-11-05T08:30:00Z", null, null, null));
        Instant later = Instant.parse("2026-11-05T06:45:00Z"); // 1 sa 45 dk kala
        ExamReminderJob laterJob = new ExamReminderJob(jdbc, notifications, null, Clock.fixed(later, ZoneOffset.UTC));
        assertEquals(1, laterJob.run(later));
        assertEquals(List.of("Uzak"), sentTitles());
    }

    @Test
    void editingTheTimeViaServiceReArmsTheReminder() {
        var created = exams.create(uid, new ExamRequest(null, "Vize", "VIZE", "2026-11-05T08:30:00Z", null, null, null));
        Instant later = Instant.parse("2026-11-05T06:45:00Z");
        ExamReminderJob laterJob = new ExamReminderJob(jdbc, notifications, null, Clock.fixed(later, ZoneOffset.UTC));
        assertEquals(1, laterJob.run(later));
        // Sinav bir gun ertelendi; yeni saat uzakta -> iz starts_at'ten farkli kalir, yeniden hak eder.
        exams.update(uid, created.id(), new ExamRequest(null, null, null, "2026-11-06T08:30:00Z", null, null, null));
        Instant later2 = Instant.parse("2026-11-06T06:45:00Z");
        ExamReminderJob laterJob2 = new ExamReminderJob(jdbc, notifications, null, Clock.fixed(later2, ZoneOffset.UTC));
        assertEquals(1, laterJob2.run(later2));
        assertEquals(2, sent().size());
        // Yalniz not/salon degisikligi (saat ayni) yeniden hatirlatma uretmez.
        exams.update(uid, created.id(), new ExamRequest(null, null, null, null, null, "B-3", "not"));
        assertEquals(0, laterJob2.run(later2));
    }

    // ---------------- dayaniklilik ----------------

    @Test
    void oneUsersFailureDoesNotStopOthersAndIsRetried() {
        exam(uid, "Bozuk", in(Duration.ofMinutes(100)), null);
        exam(uid2, "Saglam", in(Duration.ofMinutes(101)), null);
        doAnswer(inv -> {
            throw new IllegalStateException("fcm");
        }).when(notifications).sendTemplate(eq(uid), any(), any(), any(), any(String[].class));

        assertEquals(1, job.run(NOW));
        assertEquals(2, sent().size());
        // Basarisiz olanin izi geri alindi: sonraki dakika tekrar denenir; saglam olan tekrar gonderilmez.
        Long marked = jdbc.queryForObject("SELECT COUNT(*) FROM tt_exam WHERE reminded_starts_at IS NOT NULL", Long.class);
        assertEquals(1L, marked);
        assertNull(jdbc.queryForObject("SELECT reminded_starts_at FROM tt_exam WHERE user_id = ?", Timestamp.class, uid));
    }

    @Test
    void manyExamsAreProcessedInBatches() {
        int n = ExamReminderJob.BATCH * 2 + 37;
        for (int i = 0; i < n; i++) {
            jdbc.update("INSERT INTO tt_exam (user_id, title, type, starts_at) VALUES (?, ?, 'QUIZ', ?)", i % 2 == 0 ? uid : uid2,
                    "Q" + i, Timestamp.from(in(Duration.ofMinutes(60 + i % 50))));
        }
        assertEquals(n, job.run(NOW));
        assertEquals(0, job.run(NOW));
        assertEquals(n, sent().size());
    }

    @Test
    void scheduledRunsInsideTheSchedulerLock() {
        SchedulerLock lock = mock(SchedulerLock.class);
        ExamReminderJob locked = new ExamReminderJob(jdbc, notifications, lock, clock);
        exam(uid, "Vize", in(Duration.ofMinutes(100)), null);
        // Kilit alinamadi (baska ornek / Redis yok): gorev calismaz, hata da sizmaz.
        locked.scheduled();
        verify(lock).tryRun(eq("exam-reminder"), any(Duration.class), any(Runnable.class));
        assertEquals(0, sent().size());
        assertEquals(1L, jdbc.queryForObject("SELECT COUNT(*) FROM tt_exam WHERE reminded_starts_at IS NULL", Long.class));
    }
}
