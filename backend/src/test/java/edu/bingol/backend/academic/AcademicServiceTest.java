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
import edu.bingol.backend.notification.NotificationService;
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
    DepartmentAnnouncementService ann;
    AnnouncementNotifier notifier;
    NotificationService notifications;
    long uid;
    long uid2;

    @BeforeEach
    void setUp() {
        for (String t : List.of("announcement_read", "department_announcement", "academic_event", "exam_schedule", "tt_exam",
                "tt_session", "tt_course", "tt_semester")) {
            jdbc.update("DELETE FROM " + t);
        }
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'acd-%'");
        uid = user("acd-1@bingol.edu.tr", "Bilgisayar Mühendisliği", "Mühendislik Fakültesi", "2");
        uid2 = user("acd-2@bingol.edu.tr", "Hukuk", "Hukuk Fakültesi", "1");
        audience = new AcademicAudience(jdbc);
        exams = new ExamService(jdbc, audience, clock);
        tt = new TimetableService(jdbc, exams, clock);
        cal = new AcademicCalendarService(jdbc, audience, clock);
        notifications = mock(NotificationService.class);
        notifier = new AnnouncementNotifier(jdbc, notifications, clock);
        ann = new DepartmentAnnouncementService(jdbc, audience, notifier, clock);
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

    @Test
    void officialExamsFilteredByProfile() {
        exams.adminCreate(null, new ExamScheduleRequest("Genel", "FINAL", "2026-2027 Güz", null, null, null, null, "2026-12-20T10:00", null, null, null, true));
        exams.adminCreate(null, new ExamScheduleRequest("BM Final", "FINAL", "2026-2027 Güz", "BIL201", null, "bilgisayar mühendisliği", "2",
                "2026-12-21T10:00", null, "B-204", null, true));
        exams.adminCreate(null, new ExamScheduleRequest("BM 3. sinif", "FINAL", "2026-2027 Güz", null, null, "Bilgisayar Mühendisliği", "3",
                "2026-12-22T10:00", null, null, null, true));
        exams.adminCreate(null, new ExamScheduleRequest("Taslak", "FINAL", "2026-2027 Güz", null, null, null, null, "2026-12-23T10:00", null, null, null, false));
        exams.adminCreate(null, new ExamScheduleRequest("Hukuk", "FINAL", "2026-2027 Güz", null, null, "Hukuk", "1", "2026-12-24T10:00", null, null, null, true));
        OfficialExamsView mine = exams.official(uid, false);
        assertEquals(List.of("Genel", "BM Final"), mine.items().stream().map(OfficialExamView::title).toList());
        assertTrue(mine.profileComplete());
        assertEquals(4, exams.official(uid, true).items().size());
        assertEquals(List.of("Genel", "Hukuk"), exams.official(uid2, false).items().stream().map(OfficialExamView::title).toList());
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

    // ---------------- duyurular ----------------

    static AnnouncementRequest annReq(String title, String dept, String grade, boolean pinned, String publishAt, String expiresAt) {
        return new AnnouncementRequest(title, "Metin " + title, dept, null, grade, pinned, publishAt, expiresAt, null, true, false);
    }

    @Test
    void feedScopePinnedOrderAndVisibility() {
        ann.create(null, annReq("Genel", null, null, false, "2026-11-01T09:00", null));
        ann.create(null, annReq("BM", "Bilgisayar Mühendisliği", null, false, "2026-11-01T10:00", null));
        ann.create(null, annReq("BM 3", "Bilgisayar Mühendisliği", "3", false, "2026-11-01T11:00", null));
        ann.create(null, annReq("Hukuk", "Hukuk", null, false, "2026-11-01T12:00", null));
        ann.create(null, annReq("Sabit", null, null, true, "2026-10-01T09:00", null));
        ann.create(null, annReq("Gelecek", null, null, false, "2026-12-01T09:00", null));
        ann.create(null, annReq("Suresi doldu", null, null, false, "2026-10-01T09:00", "2026-10-15T09:00"));
        AdminAnnouncementView draft = ann.create(null, new AnnouncementRequest("Taslak", "x", null, null, null, false, null, null, null, false, false));
        assertFalse(draft.published());

        AnnouncementPage mine = ann.feed(uid, "mine", null, 20);
        assertEquals(List.of("Sabit", "BM", "Genel"), mine.items().stream().map(AnnouncementView::title).toList());
        assertNull(mine.nextCursor());
        assertEquals(List.of("Sabit", "Hukuk", "BM 3", "BM", "Genel"), ann.feed(uid, "all", null, 20).items().stream().map(AnnouncementView::title).toList());
        assertEquals(List.of("Sabit", "Hukuk", "Genel"), ann.feed(uid2, "mine", null, 20).items().stream().map(AnnouncementView::title).toList());

        // imecli sayfalama (pinned ilk)
        AnnouncementPage p1 = ann.feed(uid, "all", null, 2);
        assertEquals(List.of("Sabit", "Hukuk"), p1.items().stream().map(AnnouncementView::title).toList());
        assertNotNull(p1.nextCursor());
        AnnouncementPage p2 = ann.feed(uid, "all", p1.nextCursor(), 2);
        assertEquals(List.of("BM 3", "BM"), p2.items().stream().map(AnnouncementView::title).toList());
        AnnouncementPage p3 = ann.feed(uid, "all", p2.nextCursor(), 2);
        assertEquals(List.of("Genel"), p3.items().stream().map(AnnouncementView::title).toList());
        assertNull(p3.nextCursor());
        assertEquals("ANNOUNCEMENT_CURSOR_INVALID", assertThrows(ApiException.class, () -> ann.feed(uid, "mine", "abc", 5)).code());
    }

    @Test
    void scheduledBecomesVisibleWhenDue() {
        AdminAnnouncementView a = ann.create(null, annReq("Zamanli", null, null, false, "2026-11-02T11:00", null));
        assertEquals(0, ann.feed(uid, "mine", null, 20).items().size());
        assertEquals("ANNOUNCEMENT_NOT_FOUND", assertThrows(ApiException.class, () -> ann.get(uid, a.id())).code());
        Clock later = Clock.fixed(NOW.plusSeconds(3600), ZoneOffset.UTC);
        DepartmentAnnouncementService annLater = new DepartmentAnnouncementService(jdbc, audience, notifier, later);
        assertEquals(1, annLater.feed(uid, "mine", null, 20).items().size());
        assertEquals(1, ann.adminList(0, 10, "scheduled", null).items().size());
        assertEquals(0, ann.adminList(0, 10, "active", null).items().size());
    }

    @Test
    void readTrackingAndUnreadCount() {
        AdminAnnouncementView a1 = ann.create(null, annReq("A1", null, null, false, "2026-11-01T09:00", null));
        ann.create(null, annReq("A2", "Bilgisayar Mühendisliği", null, false, "2026-11-01T10:00", null));
        ann.create(null, annReq("H", "Hukuk", null, false, "2026-11-01T10:00", null));
        assertEquals(2, ann.unreadCount(uid));
        assertEquals(2, ann.unreadCount(uid2));
        AnnouncementView full = ann.get(uid, a1.id());
        assertTrue(full.read());
        assertEquals(1, ann.unreadCount(uid));
        ann.markRead(uid, a1.id()); // idempotent
        assertEquals(1, ann.unreadCount(uid));
        assertTrue(ann.feed(uid, "mine", null, 20).items().stream().filter(x -> x.id().equals(a1.id())).findFirst().orElseThrow().read());
        ann.markAllRead(uid);
        assertEquals(0, ann.unreadCount(uid));
        assertEquals(2, ann.unreadCount(uid2), "baska kullanici etkilenmez");
        assertEquals(1, ann.adminGet(a1.id()).readCount());
    }

    @Test
    void listBodyTruncatedDetailFull() {
        String body = "x".repeat(500);
        AdminAnnouncementView a = ann.create(null, new AnnouncementRequest("Uzun", body, null, null, null, false, null, null, null, true, false));
        AnnouncementView item = ann.feed(uid, "mine", null, 5).items().get(0);
        assertTrue(item.bodyTruncated());
        assertEquals(200, item.body().length());
        assertEquals(500, ann.get(uid, a.id()).body().length());
    }

    @Test
    void adminValidation() {
        assertEquals("ANNOUNCEMENT_INVALID", assertThrows(ApiException.class,
                () -> ann.create(null, new AnnouncementRequest(" ", "b", null, null, null, null, null, null, null, null, null))).code());
        assertEquals("ANNOUNCEMENT_INVALID", assertThrows(ApiException.class,
                () -> ann.create(null, new AnnouncementRequest("t", "b".repeat(4001), null, null, null, null, null, null, null, null, null))).code());
        assertEquals("ANNOUNCEMENT_INVALID", assertThrows(ApiException.class,
                () -> ann.create(null, new AnnouncementRequest("t", "b", null, null, "9", null, null, null, null, null, null))).code());
        assertEquals("ANNOUNCEMENT_INVALID", assertThrows(ApiException.class,
                () -> ann.create(null, annReq("t", null, null, false, "2026-11-05T10:00", "2026-11-04T10:00"))).code());
        for (String bad : List.of("http://x.com/a.pdf", "javascript:alert(1)", "ftp://x.com/a", "not a url")) {
            assertEquals("ANNOUNCEMENT_URL_INVALID", assertThrows(ApiException.class,
                    () -> ann.create(null, new AnnouncementRequest("t", "b", null, null, null, null, null, null, bad, null, null))).code(), bad);
        }
        AdminAnnouncementView ok = ann.create(null, new AnnouncementRequest("t", "b", null, null, "2", null, null, null, "https://bingol.edu.tr/a.pdf", null, null));
        assertEquals("https://bingol.edu.tr/a.pdf", ok.attachmentUrl());
        AdminAnnouncementView up = ann.update(null, ok.id(), new AnnouncementRequest(null, null, null, null, null, true, null, null, "", null, null));
        assertTrue(up.pinned());
        assertNull(up.attachmentUrl());
        assertEquals(1, ann.adminList(0, 10, "all", "T").total());
    }

    @Test
    void audienceCountAndNotifyOnce() {
        user("acd-3@bingol.edu.tr", "Bilgisayar Mühendisliği", "Mühendislik Fakültesi", "3");
        jdbc.update("UPDATE app_user SET status = 'SUSPENDED' WHERE email = 'acd-2@bingol.edu.tr'");
        assertEquals(2, ann.audienceCount("bilgisayar mühendisliği", null, null));
        assertEquals(1, ann.audienceCount("Bilgisayar Mühendisliği", null, "3"));
        assertEquals(0, ann.audienceCount("Hukuk", null, null), "askidaki kullanici sayilmaz");
        assertEquals("ANNOUNCEMENT_INVALID", assertThrows(ApiException.class, () -> ann.audienceCount(null, null, "99")).code());

        // notify=true, hemen gorunur: bir kez gonderilir
        AdminAnnouncementView a = ann.create(null, new AnnouncementRequest("Bildirimli", "Govde", "Bilgisayar Mühendisliği", null, null, false,
                null, null, null, true, true));
        org.mockito.Mockito.verify(notifications, org.mockito.Mockito.times(1)).sendBulk(org.mockito.ArgumentMatchers.anyCollection(),
                org.mockito.ArgumentMatchers.eq(edu.bingol.backend.notification.NotificationType.ANNOUNCEMENT),
                org.mockito.ArgumentMatchers.eq("Bildirimli"), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.anyMap());
        assertNotNull(ann.adminGet(a.id()).notifiedAt());
        notifier.dispatchDue();
        ann.update(null, a.id(), new AnnouncementRequest("Bildirimli 2", null, null, null, null, null, null, null, null, null, null));
        org.mockito.Mockito.verify(notifications, org.mockito.Mockito.times(1)).sendBulk(org.mockito.ArgumentMatchers.anyCollection(),
                org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.anyMap());

        // zamanlanmis notify: zamani gelince tarama gonderir
        ann.create(null, new AnnouncementRequest("Sonra", "Govde", null, null, null, false, "2026-11-02T11:00", null, null, true, true));
        notifier.dispatchDue();
        org.mockito.Mockito.verify(notifications, org.mockito.Mockito.never()).sendBulk(org.mockito.ArgumentMatchers.anyCollection(),
                org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.eq("Sonra"), org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.anyMap());
        new AnnouncementNotifier(jdbc, notifications, Clock.fixed(NOW.plusSeconds(3600), ZoneOffset.UTC)).dispatchDue();
        org.mockito.Mockito.verify(notifications, org.mockito.Mockito.times(1)).sendBulk(org.mockito.ArgumentMatchers.anyCollection(),
                org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.eq("Sonra"), org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.anyMap());
    }

    // ---------------- KVKK ----------------

    @Test
    void purgeAndExport() {
        CourseView c = tt.createCourse(uid, course("A", 1, "09:00", "10:00", false));
        tt.createSemester(uid, new SemesterRequest("Güz", "2026-09-14", "2027-01-15", null));
        exams.create(uid, new ExamRequest(c.id(), "Vize", "VIZE", "2026-11-10T10:00", null, null, null));
        AdminAnnouncementView a = ann.create(null, annReq("G", null, null, false, null, null));
        ann.get(uid, a.id());
        var data = tt.exportData(uid);
        assertEquals(1, ((List<?>) data.get("courses")).size());
        assertEquals(1, ((List<?>) data.get("exams")).size());
        new AcademicAccountPurger(jdbc).purge(uid);
        for (String t : List.of("tt_course", "tt_session", "tt_exam", "tt_semester", "announcement_read")) {
            assertEquals(0L, jdbc.queryForObject("SELECT COUNT(*) FROM " + t, Long.class), t);
        }
    }
}
