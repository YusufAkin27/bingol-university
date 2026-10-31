package edu.bingol.backend.academic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.notification.NotificationPref;
import edu.bingol.backend.notification.NotificationPrefRepository;
import edu.bingol.backend.notification.NotificationPrefService;
import edu.bingol.backend.notification.dto.NotificationDtos.PrefsUpdate;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Sinav hatirlatmasi gercek NotificationService ile: alicinin dilinde metin, uygulama ici kutuya dusme, akademik
 * bayrak / ana duyuru bayragi kapaliyken gonderilmemesi. FCM kapali: push atlanir, kutu kaydi yazilir.
 */
// Test profilinde ceviri kaynagi tanimli degil: gercek tr/en/ar metinlerini sinamak icin acikca verilir.
@SpringBootTest(properties = "spring.messages.basename=i18n/messages")
class ExamReminderDeliveryTest {

    static final Instant NOW = Instant.parse("2026-11-02T07:00:00Z");

    @Autowired NotificationService notifications;
    @Autowired NotificationPrefRepository prefs;
    @Autowired NotificationPrefService prefService;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;

    ExamReminderJob job;

    @BeforeEach
    void setUp() {
        jdbc.update("DELETE FROM tt_exam");
        job = new ExamReminderJob(jdbc, notifications, null, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private User user(String lang, boolean announcements, boolean academic) {
        User u = new User();
        u.setEmail("exd" + UUID.randomUUID().toString().substring(0, 10) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Sinav");
        u.setEmailVerified(true);
        u.setLanguage(lang);
        u = users.saveAndFlush(u);
        NotificationPref p = NotificationPref.defaults(u.getId());
        p.setAnnouncements(announcements);
        p.setAcademicAnnouncements(academic);
        prefs.saveAndFlush(p);
        return u;
    }

    private void exam(User u, String title, String room) {
        jdbc.update("INSERT INTO tt_exam (user_id, title, type, starts_at, room) VALUES (?, ?, 'FINAL', ?, ?)", u.getId(), title,
                Timestamp.from(Instant.parse("2026-11-02T08:30:00Z")), room); // 11:30 Istanbul, 1 sa 30 dk sonra
    }

    private List<Map<String, Object>> inbox(User u) {
        return jdbc.queryForList("SELECT title, body, type, subtype, data FROM notification WHERE user_id = ?", u.getId());
    }

    @Test
    void textIsInTheRecipientsLanguage() {
        User tr = user("tr", true, true);
        User en = user("en", true, true);
        User ar = user("ar", true, true);
        exam(tr, "Veri Yapıları", "A-12");
        exam(en, "Calculus", null);
        exam(ar, "Physics", "B-3");
        assertEquals(3, job.run(NOW));

        Map<String, Object> t = inbox(tr).get(0);
        assertEquals("Sınav hatırlatması", t.get("TITLE"));
        assertEquals("Veri Yapıları sınavına 2 saat kaldı (11:30, A-12)", t.get("BODY"));
        assertEquals("ANNOUNCEMENT", t.get("TYPE"));
        assertEquals("EXAM_REMINDER", t.get("SUBTYPE"));
        assertTrue(String.valueOf(t.get("DATA")).contains("\"target\":\"EXAM\""));

        Map<String, Object> e = inbox(en).get(0);
        assertEquals("Exam reminder", e.get("TITLE"));
        assertEquals("2 hours left until your Calculus exam (11:30)", e.get("BODY"));

        Map<String, Object> a = inbox(ar).get(0);
        assertEquals("تذكير بالامتحان", a.get("TITLE"));
        assertTrue(String.valueOf(a.get("BODY")).contains("Physics"));
        assertTrue(String.valueOf(a.get("BODY")).contains("B-3"));
    }

    @Test
    void academicFlagOrMainAnnouncementFlagOffSuppressesTheReminder() {
        User academicOff = user("tr", true, false);
        User mainOff = user("tr", false, true);
        User on = user("tr", true, true);
        exam(academicOff, "A", null);
        exam(mainOff, "B", null);
        exam(on, "C", null);
        job.run(NOW);
        assertEquals(0, inbox(academicOff).size());
        assertEquals(0, inbox(mainOff).size());
        assertEquals(1, inbox(on).size());
    }

    @Test
    void userWithoutPrefRowGetsTheReminder() {
        User u = new User();
        u.setEmail("exd" + UUID.randomUUID().toString().substring(0, 10) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName("Sinav");
        u.setEmailVerified(true);
        u = users.saveAndFlush(u);
        exam(u, "Satirsiz", null);
        assertEquals(1, job.run(NOW));
        assertEquals(1, inbox(u).size());
    }

    @Test
    void examReminderSubtypeToggleDrivesTheAcademicFlag() {
        User u = user("tr", true, true);
        prefService.update(u.getId(), new PrefsUpdate(null, null, null, null, null, null, Map.of("EXAM_REMINDER", false)));
        assertEquals(false, prefs.findById(u.getId()).orElseThrow().isAcademicAnnouncements());
        assertEquals(false, prefService.get(u.getId()).subtypes().get("EXAM_REMINDER"));
        exam(u, "Kapali", null);
        job.run(NOW);
        assertEquals(0, inbox(u).size());
    }
}
