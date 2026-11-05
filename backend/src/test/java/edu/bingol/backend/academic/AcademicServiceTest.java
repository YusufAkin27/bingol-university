package edu.bingol.backend.academic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.academic.AcademicDtos.*;
import edu.bingol.backend.common.ApiException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Servis davranislari H2 uzerinde (duz SQL, PostgreSQL ile ortak alt kume). Saat sabit:
 * 2026-11-02 Pazartesi 10:00 Istanbul (= 07:00Z).
 */
@SpringBootTest
class AcademicServiceTest {

    static final Instant NOW = Instant.parse("2026-11-02T07:00:00Z");

    @Autowired JdbcTemplate jdbc;

    Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
    AcademicAudience audience;
    ExamService exams;
    TimetableService tt;
    AcademicCalendarService cal;
    long uid;
    long uid2;

    @BeforeEach
    void setUp() {
        for (String t : List.of("academic_event", "tt_exam",
                "tt_session", "tt_course", "tt_semester", "tt_official_seed")) {
            jdbc.update("DELETE FROM " + t);
        }
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'acd-%'");
        uid = user("acd-1@bingol.edu.tr", "Bilgisayar Mühendisliği", "Mühendislik Fakültesi", "2");
        uid2 = user("acd-2@bingol.edu.tr", "Hukuk", "Hukuk Fakültesi", "1");
        audience = new AcademicAudience(jdbc);
        exams = new ExamService(jdbc, clock);
        tt = new TimetableService(jdbc, exams, clock);
        cal = new AcademicCalendarService(jdbc, audience, clock);
    }

    long user(String email, String dept, String faculty, String grade) {
        jdbc.update("INSERT INTO app_user (email, password_hash, display_name, email_verified, role, status, department, faculty, "
                + "grade, language, show_email, created_at) VALUES (?, 'x', 'T', TRUE, 'USER', 'ACTIVE', ?, ?, ?, 'tr', FALSE, CURRENT_TIMESTAMP)",
                email, dept, faculty, grade);
        return jdbc.queryForObject("SELECT id FROM app_user WHERE email = ?", Long.class, email);
    }

    static CourseRequest course(String name, int day, String s, String e, boolean force) {
        return new CourseRequest(name, null, null, null, null, null, force, null, day, s, e, "A1");
    }

    // ---------------- ders programi ----------------

    @Test
    void createCourseAndConflict() {
        CourseView c = tt.createCourse(uid, new CourseRequest("Veri Yapıları", "BIL201", "Dr. Ayşe", "blue", null, null, null,
                List.of(new SessionIn(1, "09:00", "10:50", "B-204"), new SessionIn(3, "13:00", "14:50", "Lab")),
                null, null, null, null));
        assertEquals(2, c.sessions().size());
        assertEquals("blue", c.color());
        assertEquals("09:00", c.sessions().get(0).start());

        ApiException ex = assertThrows(ApiException.class, () -> tt.createCourse(uid, course("Fizik", 1, "10:00", "11:00", false)));
        assertEquals("COURSE_CONFLICT", ex.code());
        assertEquals(409, ex.status().value());
        // bitisik ders cakismaz
        tt.createCourse(uid, course("Kimya", 1, "10:50", "11:40", false));
        // force ile izin
        CourseView forced = tt.createCourse(uid, course("Fizik", 1, "10:00", "11:00", true));
        assertNotNull(forced.id());
        // baska kullanici etkilenmez
        tt.createCourse(uid2, course("Fizik", 1, "10:00", "11:00", false));
        assertEquals(3, tt.timetable(uid, null).courses().size());
    }

    /** Sozlesme A: kod, renk, not, derslik zorunlu degil; renk otomatik atanir. */
    @Test
    void createCourseWithOnlyNameAndSession() {
        CourseView c = tt.createCourse(uid, new CourseRequest("Fizik", null, null, null, null, null, null,
                List.of(new SessionIn(2, "09:00", "10:00", null)), null, null, null, null));
        assertEquals("Fizik", c.name());
        assertNull(c.code());
        assertNull(c.note());
        assertNull(c.instructor());
        assertNull(c.sessions().get(0).room());
        assertTrue(TimetableLogic.COLORS.contains(c.color()), "renk otomatik atanir");
        // ayni ad her zaman ayni rengi alir (belirleyici)
        assertEquals(c.color(), tt.createCourse(uid2, new CourseRequest("Fizik", "", "", "", "", null, null,
                List.of(new SessionIn(2, "09:00", "10:00", "")), null, null, null, null)).color());
        // duzenleme de yalniz istenen alani ister
        CourseView u = tt.updateCourse(uid, c.id(), new CourseRequest("Fizik 1", null, null, null, null, null, null,
                null, null, null, null, null));
        assertEquals("Fizik 1", u.name());
        assertEquals(c.color(), u.color());
        assertEquals(1, u.sessions().size());
    }

    @Test
    void validationErrors() {
        assertEquals("COURSE_INVALID_DAY", assertThrows(ApiException.class,
                () -> tt.createCourse(uid, course("X", 8, "09:00", "10:00", false))).code());
        assertEquals("COURSE_INVALID_DAY", assertThrows(ApiException.class,
                () -> tt.createCourse(uid, course("X", 0, "09:00", "10:00", false))).code());
        assertEquals("COURSE_INVALID_TIME", assertThrows(ApiException.class,
                () -> tt.createCourse(uid, course("X", 1, "10:00", "09:00", false))).code());
        assertEquals("COURSE_INVALID_TIME", assertThrows(ApiException.class,
                () -> tt.createCourse(uid, course("X", 1, "9am", "10:00", false))).code());
        assertEquals("COURSE_SESSIONS_REQUIRED", assertThrows(ApiException.class,
                () -> tt.createCourse(uid, new CourseRequest("X", null, null, null, null, null, null, null, null, null, null, null))).code());
        assertEquals("COURSE_INVALID", assertThrows(ApiException.class,
                () -> tt.createCourse(uid, course(" ", 1, "09:00", "10:00", false))).code());
        assertEquals("COURSE_FIELD_TOO_LONG", assertThrows(ApiException.class,
                () -> tt.createCourse(uid, course("a".repeat(121), 1, "09:00", "10:00", false))).code());
        assertEquals("COURSE_COLOR_INVALID", assertThrows(ApiException.class,
                () -> tt.createCourse(uid, new CourseRequest("X", null, null, "neon", null, null, null, null, 1, "09:00", "10:00", null))).code());
    }

    @Test
    void patchReplacesSessionsAndChecksConflictExcludingSelf() {
        CourseView a = tt.createCourse(uid, course("A", 2, "09:00", "10:00", false));
        tt.createCourse(uid, course("B", 2, "11:00", "12:00", false));
        // kendi saatini guncelle: kendisiyle cakisma sayilmaz
        CourseView a2 = tt.updateCourse(uid, a.id(), new CourseRequest(null, null, "Hoca", null, null, null, null,
                List.of(new SessionIn(2, "09:30", "10:30", null)), null, null, null, null));
        assertEquals("Hoca", a2.instructor());
        assertEquals(1, a2.sessions().size());
        assertEquals("09:30", a2.sessions().get(0).start());
        // B ile cakisan guncelleme
        assertEquals("COURSE_CONFLICT", assertThrows(ApiException.class, () -> tt.updateCourse(uid, a.id(),
                new CourseRequest(null, null, null, null, null, null, null, List.of(new SessionIn(2, "11:30", "12:30", null)),
                        null, null, null, null))).code());
        // baskasinin dersi 404
        assertEquals("COURSE_NOT_FOUND", assertThrows(ApiException.class, () -> tt.updateCourse(uid2, a.id(),
                new CourseRequest("Z", null, null, null, null, null, null, null, null, null, null, null))).code());
        tt.deleteCourse(uid, a.id());
        assertEquals(1, tt.timetable(uid, null).courses().size());
    }

    @Test
    void importLimitsAndAtomic() {
        List<CourseRequest> many = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            List<SessionIn> ss = new ArrayList<>();
            for (int d = 1; d <= 11; d++) {
                ss.add(new SessionIn((d % 7) + 1, "0" + (i + 1) + ":00", "0" + (i + 1) + ":30", null));
            }
            many.add(new CourseRequest("C" + i, null, null, null, null, null, null, ss, null, null, null, null));
        }
        assertEquals("IMPORT_TOO_LARGE", assertThrows(ApiException.class,
                () -> tt.importCourses(uid, new ImportRequest(null, false, true, many))).code());
        // 12'den fazla oturum bir derste
        List<SessionIn> thirteen = new ArrayList<>();
        for (int i = 0; i < 13; i++) {
            thirteen.add(new SessionIn(1, "0" + (i % 9) + ":00", "0" + (i % 9) + ":10", null));
        }
        assertEquals("SESSION_LIMIT", assertThrows(ApiException.class, () -> tt.importCourses(uid, new ImportRequest(null, false, true,
                List.of(new CourseRequest("Y", null, null, null, null, null, null, thirteen, null, null, null, null))))).code());
        // gecerli + ikinci hatali: hicbiri yazilmaz
        List<CourseRequest> mixed = List.of(course("OK", 1, "09:00", "10:00", false), course("BAD", 1, "09:30", "10:30", false));
        assertEquals("COURSE_CONFLICT", assertThrows(ApiException.class,
                () -> tt.importCourses(uid, new ImportRequest(null, false, false, mixed))).code());
    }

    @Test
    void importOkAndReplace() {
        ImportResult r = tt.importCourses(uid, new ImportRequest(null, false, false,
                List.of(course("A", 1, "09:00", "10:00", false), course("B", 2, "09:00", "10:00", false))));
        assertEquals(2, r.created());
        ImportResult r2 = tt.importCourses(uid, new ImportRequest(null, true, false, List.of(course("C", 1, "09:00", "10:00", false))));
        assertEquals(1, r2.created());
        assertEquals(1, tt.timetable(uid, null).courses().size());
    }

    @Test
    void semestersAndCurrentScoping() {
        SemesterView s1 = tt.createSemester(uid, new SemesterRequest("Güz", "2026-09-14", "2027-01-15", null));
        assertTrue(s1.current(), "ilk donem otomatik guncel");
        SemesterView s2 = tt.createSemester(uid, new SemesterRequest("Bahar", "2027-02-15", "2027-06-04", true));
        assertTrue(s2.current());
        assertFalse(tt.semesters(uid).items().stream().filter(s -> s.id().equals(s1.id())).findFirst().orElseThrow().current());
        assertEquals("SEMESTER_INVALID", assertThrows(ApiException.class,
                () -> tt.createSemester(uid, new SemesterRequest("X", "2027-02-15", "2027-02-15", null))).code());
        // ders guncel doneme (Bahar) yazilir; Guz aliyla cakisma aranmaz
        CourseView c = tt.createCourse(uid, course("A", 1, "09:00", "10:00", false));
        assertEquals(s2.id(), c.semesterId());
        tt.createCourse(uid, new CourseRequest("B", null, null, null, null, s1.id(), null, null, 1, "09:00", "10:00", null));
        assertEquals(1, tt.timetable(uid, s1.id()).courses().size());
        // Bahar bugun (Kasim 2026) disinda: bugun gorunumunde ders yok
        assertEquals(0, tt.today(uid, null).items().size());
        tt.updateSemester(uid, s1.id(), new SemesterRequest(null, null, null, true));
        assertEquals(1, tt.today(uid, null).items().size(), "Guz guncel ve bugun donem icinde");
        tt.deleteSemester(uid, s1.id());
        assertNull(jdbc.queryForObject("SELECT semester_id FROM tt_course WHERE name = 'B'", Long.class));
        assertEquals("SEMESTER_NOT_FOUND", assertThrows(ApiException.class, () -> tt.timetable(uid2, s2.id())).code());
    }

    @Test
    void officialSemesterFromCalendar() {
        assertNull(tt.semesters(uid).officialCurrent());
        assertEquals("NO_OFFICIAL_SEMESTER", assertThrows(ApiException.class, () -> tt.semesterFromOfficial(uid)).code());
        cal.create(null, new AcademicEventRequest("DONEM_BASLANGIC", "2026-2027 Güz", "2026-09-14", "2027-01-15", true, null, null, true));
        cal.create(null, new AcademicEventRequest("DONEM_BASLANGIC", "Taslak", "2026-10-01", "2027-01-15", true, null, null, false));
        assertEquals("2026-2027 Güz", tt.semesters(uid).officialCurrent().name());
        SemesterView s = tt.semesterFromOfficial(uid);
        assertEquals("2026-09-14", s.startDate());
        assertEquals("2027-01-15", s.endDate());
        assertTrue(s.current());
    }

    @Test
    void todayWeekAndNext() {
        // Pazartesi 2026-11-02, simdi 10:00
        tt.createCourse(uid, course("Sabah", 1, "08:00", "09:30", false));
        tt.createCourse(uid, course("Suren", 1, "09:30", "10:30", false));
        tt.createCourse(uid, course("Ogle", 1, "13:00", "14:00", false));
        tt.createCourse(uid, course("Sali", 2, "09:00", "10:00", false));
        TodayView t = tt.today(uid, null);
        assertEquals("2026-11-02", t.date());
        assertEquals(1, t.dayOfWeek());
        assertEquals(List.of("PAST", "ONGOING", "UPCOMING"), t.items().stream().map(DayItem::status).toList());
        assertEquals("Ogle", t.next().name());
        assertEquals(180, t.next().minutesUntil());
        // gunun tum dersleri bitince sonraki gun
        WeekView w = tt.week(uid, "2026-11-04");
        assertEquals("2026-11-02", w.weekStart());
        assertEquals(7, w.days().size());
        assertEquals(3, w.days().get(0).items().size());
        assertEquals(1, w.days().get(1).items().size());
        assertEquals("UPCOMING", w.days().get(1).items().get(0).status());
        // reminders
        RemindersView r = tt.reminders(uid, 2);
        assertEquals(List.of("Ogle", "Sali"), r.sessions().stream().map(ReminderSession::name).toList());
        assertEquals("2026-11-02T13:00:00+03:00", r.sessions().get(0).startsAt());
    }

    @Test
    void icsExportFromService() {
        tt.createSemester(uid, new SemesterRequest("Güz", "2026-09-14", "2027-01-15", null));
        tt.createCourse(uid, course("Veri", 1, "09:00", "10:00", false));
        String ics = tt.exportIcs(uid, null);
        assertTrue(ics.contains("RRULE:FREQ=WEEKLY;BYDAY=MO;UNTIL=20270115T205959Z"));
        assertTrue(ics.contains("DTSTART;TZID=Europe/Istanbul:20260914T090000"));
    }

    // ---------------- sinavlar ----------------

    @Test
    void personalExams() {
        CourseView c = tt.createCourse(uid, course("Veri", 1, "09:00", "10:00", false));
        ExamView e = exams.create(uid, new ExamRequest(c.id(), "Vize 1", "vize", "2026-11-10T10:00", "2026-11-10T11:30", "B-204", null));
        assertEquals("VIZE", e.type());
        assertEquals("Veri", e.courseName());
        assertEquals("2026-11-10T10:00:00+03:00", e.startsAt());
        exams.create(uid, new ExamRequest(null, "Eski", "QUIZ", "2026-10-01T10:00", null, null, null));
        exams.create(uid, new ExamRequest(null, "Uzak", "FINAL", "2027-03-01T10:00", null, null, null));
        List<ExamView> up = exams.upcoming(uid, 30);
        assertEquals(List.of("Vize 1"), up.stream().map(ExamView::title).toList());
        assertEquals(3, exams.list(uid, null, null).size());
        assertEquals("EXAM_INVALID", assertThrows(ApiException.class,
                () -> exams.create(uid, new ExamRequest(null, "X", "ZZZ", "2026-11-10T10:00", null, null, null))).code());
        assertEquals("EXAM_INVALID", assertThrows(ApiException.class,
                () -> exams.create(uid, new ExamRequest(null, "X", "VIZE", "2026-11-10T10:00", "2026-11-10T09:00", null, null))).code());
        assertEquals("COURSE_NOT_FOUND", assertThrows(ApiException.class,
                () -> exams.create(uid2, new ExamRequest(c.id(), "X", "VIZE", "2026-11-10T10:00", null, null, null))).code());
        assertEquals("EXAM_NOT_FOUND", assertThrows(ApiException.class, () -> exams.delete(uid2, e.id())).code());
        ExamView p = exams.update(uid, e.id(), new ExamRequest(null, "Vize 1 (yeni)", null, null, "", null, null));
        assertEquals("Vize 1 (yeni)", p.title());
        assertNull(p.endsAt());
        exams.delete(uid, e.id());
    }

    // ---------------- akademik takvim ----------------

    @Test
    void calendarMonthRangeAndScope() {
        cal.create(null, new AcademicEventRequest("VIZE", "Vize haftası", "2026-11-09", "2026-11-13", true, null, null, true));
        cal.create(null, new AcademicEventRequest("TATIL", "Bölüm tatili", "2026-11-20", null, true, "Hukuk", null, true));
        cal.create(null, new AcademicEventRequest("DIGER", "Taslak", "2026-11-25", null, true, null, null, false));
        cal.create(null, new AcademicEventRequest("RESMI_TATIL", "Cumhuriyet Bayramı", "2026-10-29", "2026-10-29", true, null, null, true));
        CalendarView nov = cal.calendar(uid, "2026-11", null, null);
        assertEquals(List.of("Vize haftası"), nov.items().stream().map(AcademicEventView::title).toList());
        assertEquals(List.of("Vize haftası", "Bölüm tatili"), cal.calendar(uid2, "2026-11", null, null).items().stream().map(AcademicEventView::title).toList());
        // aralikla kesisen
        assertEquals(1, cal.calendar(uid, null, "2026-11-12", "2026-11-12").items().size());
        assertEquals("CALENDAR_RANGE_INVALID", assertThrows(ApiException.class, () -> cal.calendar(uid, null, "2026-01-01", "2028-01-01")).code());
        assertEquals("CALENDAR_RANGE_INVALID", assertThrows(ApiException.class, () -> cal.calendar(uid, null, null, null)).code());
        assertEquals("DATE_INVALID", assertThrows(ApiException.class, () -> cal.calendar(uid, "2026-13", null, null)).code());
        // sirada: bugun 2 Kasim; 29 Ekim gecmis
        assertEquals(List.of("Vize haftası"), cal.next(uid, 5).stream().map(AcademicEventView::title).toList());
    }

    @Test
    void calendarImport() {
        EventImportResult r = cal.importText(null, "# yorum\nVIZE;Vize haftası;2026-11-09;2026-11-13\n\nFINAL;Final;2026-12-21T10:00;;Hukuk\nXXX;Kotu;2026-01-01\nTATIL;Eksik\nVIZE;Hatali tarih;2026-99-99",
                true);
        assertEquals(2, r.created());
        assertEquals(List.of(5, 6, 7), r.errors().stream().map(ImportError::line).toList());
        AdminAcademicEventView v = cal.adminList(0, 10, "VIZE", null, true).items().get(0);
        assertTrue(v.allDay());
        assertEquals("2026-11-13T23:59:00+03:00", v.endsAt());
        assertFalse(cal.adminList(0, 10, "FINAL", null, null).items().get(0).allDay());
        cal.setPublished(v.id(), false);
        assertEquals(0, cal.adminList(0, 10, "VIZE", null, true).items().size());
    }

    // ---------------- KVKK ----------------

    @Test
    void purgeAndExport() {
        CourseView c = tt.createCourse(uid, course("A", 1, "09:00", "10:00", false));
        tt.createSemester(uid, new SemesterRequest("Güz", "2026-09-14", "2027-01-15", null));
        exams.create(uid, new ExamRequest(c.id(), "Vize", "VIZE", "2026-11-10T10:00", null, null, null));
        var data = tt.exportData(uid);
        assertEquals(1, ((List<?>) data.get("courses")).size());
        assertEquals(1, ((List<?>) data.get("exams")).size());
        new AcademicAccountPurger(jdbc).purge(uid);
        for (String t : List.of("tt_course", "tt_session", "tt_exam", "tt_semester")) {
            assertEquals(0L, jdbc.queryForObject("SELECT COUNT(*) FROM " + t, Long.class), t);
        }
    }
}
