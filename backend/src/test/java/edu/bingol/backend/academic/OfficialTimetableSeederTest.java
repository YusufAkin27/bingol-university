package edu.bingol.backend.academic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.academic.AcademicDtos.CourseRequest;
import edu.bingol.backend.academic.AcademicDtos.CourseView;
import edu.bingol.backend.academic.AcademicDtos.SessionIn;
import edu.bingol.backend.academic.AcademicDtos.TimetableView;
import edu.bingol.backend.academic.OfficialTimetableDtos.ApplyRequest;
import edu.bingol.backend.academic.OfficialTimetableDtos.OfficialStatus;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import java.sql.Time;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Resmi programin kisisel programa tohumlanmasi ve elle uygulanmasi (Sozlesme A, H2). */
@SpringBootTest
class OfficialTimetableSeederTest {

    static final String TERM = "2026-2027 Güz";
    static final String MYO = "Teknik Bilimler Meslek Yüksekokulu";
    static final String MYO2 = "Genç Meslek Yüksekokulu";
    static final String DEPT = "Çocuk Gelişimi";

    @Autowired JdbcTemplate jdbc;

    TimetableService tt;
    OfficialTimetableSeeder seeder;
    long batchId;
    long uid;

    @BeforeEach
    void setUp() {
        clean();
        Clock clock = Clock.fixed(Instant.parse("2026-11-02T07:00:00Z"), ZoneOffset.UTC);
        AcademicAudience audience = new AcademicAudience(jdbc);
        tt = new TimetableService(jdbc, new ExamService(jdbc, audience, clock), clock);
        OfficialTimetableService off = new OfficialTimetableService(jdbc, new CatalogService(), audience);
        seeder = new OfficialTimetableSeeder(jdbc, off, tt);
        jdbc.update("INSERT INTO official_timetable_batch (term, row_count, program_count) VALUES (?, 0, 0)", TERM);
        batchId = jdbc.queryForObject("SELECT MAX(id) FROM official_timetable_batch", Long.class);
        uid = user("ots-1@bingol.edu.tr", DEPT, "1");
    }

    @AfterEach
    void tearDown() {
        clean();
    }

    private void clean() {
        for (String t : List.of("tt_exam", "tt_session", "tt_course", "tt_semester", "tt_official_seed",
                "official_timetable_entry", "official_timetable_batch")) {
            jdbc.update("DELETE FROM " + t);
        }
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'ots-%'");
    }

    long user(String email, String dept, String grade) {
        jdbc.update("INSERT INTO app_user (email, password_hash, display_name, email_verified, role, status, department, faculty, "
                + "grade, language, show_email, created_at) VALUES (?, 'x', 'T', TRUE, 'USER', 'ACTIVE', ?, 'F', ?, 'tr', FALSE, "
                + "CURRENT_TIMESTAMP)", email, dept, grade);
        return jdbc.queryForObject("SELECT id FROM app_user WHERE email = ?", Long.class, email);
    }

    void off(String term, String unit, String dept, String grade, String grp, int day, String s, String e, String code,
             String name, String instructor) {
        off(term, unit, dept, grade, grp, day, s, e, code, name, instructor, true);
    }

    void off(String term, String unit, String dept, String grade, String grp, int day, String s, String e, String code,
             String name, String instructor, boolean published) {
        jdbc.update("INSERT INTO official_timetable_entry (batch_id, term, unit, faculty, department, program, grade, grp, "
                + "day_of_week, start_time, end_time, course_code, course_name, instructor, room, note, published) "
                + "VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'D-16', 'resmi not', ?)", batchId, term, unit, dept, dept,
                grade, grp, day, Time.valueOf(LocalTime.parse(s)), Time.valueOf(LocalTime.parse(e)), code, name, instructor,
                published);
    }

    /** Tek birimli temel program: iki ders, biri haftada iki oturum. */
    void baseProgram() {
        off(TERM, MYO, DEPT, "1", null, 1, "08:15", "10:00", "CG101", "Gelişim Psikolojisi", "Dr. Ali Veli");
        off(TERM, MYO, DEPT, "1", null, 3, "10:15", "12:00", "CG101", "Gelişim Psikolojisi", "Dr. Ali Veli");
        off(TERM, MYO, DEPT, "1", null, 2, "13:15", "15:00", null, "Çocuk Sağlığı", null);
        // alakasiz: baska sinif, baska bolum, yayinda degil
        off(TERM, MYO, DEPT, "2", null, 1, "08:15", "10:00", "CG201", "İkinci Sınıf Dersi", null);
        off(TERM, MYO, "Hukuk", "1", null, 1, "08:15", "10:00", null, "Hukuk Dersi", null);
        off(TERM, MYO, DEPT, "1", null, 4, "08:15", "10:00", null, "Gizli Ders", null, false);
    }

    @Test
    void autoSeedSingleUnitCopiesMergedCoursesWithoutOptionalFields() {
        baseProgram();
        assertTrue(seeder.autoSeed(uid));

        TimetableView v = tt.timetable(uid, null);
        assertEquals(2, v.courses().size(), "yalniz profilin sinifi ve yayindaki dersler");
        CourseView psi = v.courses().stream().filter(c -> c.name().equals("Gelişim Psikolojisi")).findFirst().orElseThrow();
        assertEquals(2, psi.sessions().size(), "ayni dersin gunleri tek derse oturum olarak toplanir");
        assertEquals(1, psi.sessions().get(0).dayOfWeek());
        assertEquals("08:15", psi.sessions().get(0).start());
        assertEquals(3, psi.sessions().get(1).dayOfWeek());
        assertEquals("Dr. Ali Veli", psi.instructor());
        for (CourseView c : v.courses()) {
            assertNull(c.code(), "ders kodu kopyalanmaz");
            assertNull(c.note(), "not kopyalanmaz");
            assertNotNull(c.color());
            assertTrue(TimetableLogic.COLORS.contains(c.color()));
            c.sessions().forEach(s -> assertNull(s.room(), "derslik kopyalanmaz"));
        }
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM tt_official_seed WHERE user_id = ? AND term = ? AND unit = ?",
                Integer.class, uid, TERM, MYO));
        OfficialStatus st = seeder.status(uid);
        assertTrue(st.available());
        assertTrue(st.applied());
        assertEquals(TERM, st.term());
        assertEquals(List.of(MYO), st.units());
    }

    @Test
    void autoSeedIsIdempotentAndNeverReseedsAfterUserDeletesEverything() {
        baseProgram();
        assertTrue(seeder.autoSeed(uid));
        assertFalse(seeder.autoSeed(uid), "dersler varken tekrar tohumlanmaz");
        assertEquals(2, tt.timetable(uid, null).courses().size());

        for (CourseView c : tt.timetable(uid, null).courses()) {
            tt.deleteCourse(uid, c.id());
        }
        assertFalse(seeder.autoSeed(uid), "isaret var: hepsi silinse de yeniden tohumlanmaz");
        assertTrue(tt.timetable(uid, null).courses().isEmpty());
    }

    @Test
    void autoSeedSkipsUsersWhoAlreadyHavePersonalCourses() {
        baseProgram();
        tt.createCourse(uid, new CourseRequest("Benim Dersim", null, null, null, null, null, null,
                List.of(new SessionIn(5, "09:00", "10:00", null)), null, null, null, null));
        assertFalse(seeder.autoSeed(uid));
        assertEquals(1, tt.timetable(uid, null).courses().size());
        assertFalse(seeder.status(uid).applied());
    }

    @Test
    void autoSeedSkippedWhenSeveralUnitsMatchAndApplyNeedsUnit() {
        off(TERM, MYO, DEPT, "1", null, 1, "08:15", "10:00", null, "Ders A", null);
        off(TERM, MYO2, DEPT, "1", null, 2, "08:15", "10:00", null, "Ders B", null);
        off(TERM, MYO2, DEPT, "1", null, 3, "08:15", "10:00", null, "Ders C", null);

        assertFalse(seeder.autoSeed(uid), "birden cok birim: otomatik tohumlanmaz");
        assertTrue(tt.timetable(uid, null).courses().isEmpty());
        OfficialStatus st = seeder.status(uid);
        assertTrue(st.available());
        assertFalse(st.applied());
        assertEquals(List.of(MYO2, MYO), st.units(), "birimler ada gore sirali");

        assertEquals("OFFICIAL_UNIT_REQUIRED", assertThrows(ApiException.class,
                () -> seeder.apply(uid, new ApplyRequest(null, null, null))).code());
        assertEquals(422, assertThrows(ApiException.class, () -> seeder.apply(uid, null)).status().value());
        ApiException nf = assertThrows(ApiException.class, () -> seeder.apply(uid, new ApplyRequest("Yok Birim", null, null)));
        assertEquals("OFFICIAL_TIMETABLE_NOT_FOUND", nf.code());
        assertEquals(404, nf.status().value());
        assertTrue(tt.timetable(uid, null).courses().isEmpty(), "hata durumunda hicbir sey yazilmaz");

        TimetableView v = seeder.apply(uid, new ApplyRequest(MYO2, null, null));
        assertEquals(2, v.courses().size());
        assertTrue(seeder.status(uid).applied());
        // birim adi AudienceKey ile eslenir (buyuk/kucuk, Turkce harf)
        assertEquals(2, seeder.apply(uid, new ApplyRequest("GENÇ MESLEK YÜKSEKOKULU", true, null)).courses().size());
    }

    @Test
    void applyReplaceDropsPersonalCoursesAndRecopies() {
        baseProgram();
        seeder.autoSeed(uid);
        CourseView mine = tt.createCourse(uid, new CourseRequest("Benim Dersim", null, null, null, null, null, null,
                List.of(new SessionIn(5, "09:00", "10:00", null)), null, null, null, null));
        tt.deleteCourse(uid, tt.timetable(uid, null).courses().stream().filter(c -> c.name().equals("Çocuk Sağlığı"))
                .findFirst().orElseThrow().id());
        assertEquals(2, tt.timetable(uid, null).courses().size());

        TimetableView v = seeder.apply(uid, new ApplyRequest(null, true, null));
        assertEquals(2, v.courses().size());
        assertTrue(v.courses().stream().noneMatch(c -> c.id().equals(mine.id()) || c.name().equals("Benim Dersim")));
        assertTrue(v.courses().stream().anyMatch(c -> c.name().equals("Çocuk Sağlığı")), "silinen resmi ders geri gelir");
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM tt_session WHERE course_id = ?", Integer.class, mine.id()));
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM tt_official_seed WHERE user_id = ?", Integer.class, uid));
    }

    @Test
    void applyWithoutReplaceChecksConflictsAndForceOverrides() {
        baseProgram();
        // resmi Pazartesi 08:15-10:00 ile cakisan kisisel ders
        tt.createCourse(uid, new CourseRequest("Cakisan", null, null, null, null, null, null,
                List.of(new SessionIn(1, "09:00", "10:00", null)), null, null, null, null));
        assertFalse(seeder.autoSeed(uid));

        ApiException ex = assertThrows(ApiException.class, () -> seeder.apply(uid, new ApplyRequest(null, null, null)));
        assertEquals("COURSE_CONFLICT", ex.code());
        assertEquals(409, ex.status().value());
        assertEquals(1, tt.timetable(uid, null).courses().size(), "cakismada hicbir sey yazilmaz");
        assertFalse(seeder.status(uid).applied());

        TimetableView v = seeder.apply(uid, new ApplyRequest(null, false, true));
        assertEquals(3, v.courses().size(), "force: mevcut ders + 2 resmi ders");
        assertTrue(seeder.status(uid).applied());
    }

    @Test
    void groupsAreMergedByCodeNameInstructorAndGroupSlotsDedupe() {
        // I. ve II. ogretim ayni gun/saat: tek oturum; farkli saat: ikisi de gelir
        off(TERM, MYO, DEPT, "1", "I. Öğretim", 1, "08:15", "10:00", "CG110", "Matematik", "Dr. A");
        off(TERM, MYO, DEPT, "1", "II. Öğretim", 1, "08:15", "10:00", "CG110", "Matematik", "Dr. A");
        off(TERM, MYO, DEPT, "1", "II. Öğretim", 4, "17:00", "18:45", "CG110", "Matematik", "Dr. A");
        // ayni ad, farkli hoca: ayri ders (kod yok, ad + hoca)
        off(TERM, MYO, DEPT, "1", null, 2, "08:15", "10:00", null, "Fizik", "Dr. B");
        off(TERM, MYO, DEPT, "1", null, 3, "08:15", "10:00", null, "Fizik", "Dr. C");
        // buyuk/kucuk ve Turkce harf farki ayni ders sayilir
        off(TERM, MYO, DEPT, "1", null, 5, "08:15", "10:00", null, "KİMYA", "Dr. D");
        off(TERM, MYO, DEPT, "1", null, 5, "10:15", "12:00", null, "kimya", "dr. d");

        assertTrue(seeder.autoSeed(uid));
        List<CourseView> cs = tt.timetable(uid, null).courses();
        assertEquals(4, cs.size(), "Matematik, Fizik(B), Fizik(C), Kimya");
        CourseView mat = cs.stream().filter(c -> c.name().equals("Matematik")).findFirst().orElseThrow();
        assertEquals(2, mat.sessions().size());
        assertEquals(2, cs.stream().filter(c -> c.name().equals("Fizik")).count());
        assertEquals(2, cs.stream().filter(c -> c.name().equalsIgnoreCase("kimya") || c.name().equals("KİMYA"))
                .findFirst().orElseThrow().sessions().size());
    }

    @Test
    void seedsIntoCurrentSemesterAndConflictsInsideOfficialProgramAreIgnored() {
        long sem = tt.createSemester(uid, new AcademicDtos.SemesterRequest("Güz", "2026-09-14", "2027-01-15", true)).id();
        // resmi programin kendi icinde cakisan iki ders (gruplar): force ile ikisi de gelir
        off(TERM, MYO, DEPT, "1", "I. Öğretim", 1, "08:15", "10:00", null, "Ders X", null);
        off(TERM, MYO, DEPT, "1", "II. Öğretim", 1, "09:00", "10:45", null, "Ders Y", null);
        assertTrue(seeder.autoSeed(uid));
        TimetableView v = tt.timetable(uid, null);
        assertEquals(2, v.courses().size());
        assertTrue(v.courses().stream().allMatch(c -> c.semesterId() != null && c.semesterId() == sem));
    }

    @Test
    void usesNewestPublishedTermOnly() {
        jdbc.update("INSERT INTO official_timetable_batch (term, row_count, program_count) VALUES ('2025-2026 Bahar', 0, 0)");
        long old = jdbc.queryForObject("SELECT MAX(id) FROM official_timetable_batch", Long.class);
        long cur = batchId;
        batchId = old;
        off("2025-2026 Bahar", MYO, DEPT, "1", null, 1, "08:15", "10:00", null, "Eski Dönem Dersi", null);
        batchId = cur;
        off(TERM, MYO, DEPT, "1", null, 2, "08:15", "10:00", null, "Yeni Dönem Dersi", null);

        assertTrue(seeder.autoSeed(uid));
        List<CourseView> cs = tt.timetable(uid, null).courses();
        assertEquals(1, cs.size());
        assertEquals("Yeni Dönem Dersi", cs.get(0).name());
        assertEquals(TERM, seeder.status(uid).term());
    }

    @Test
    void noMatchOrMissingGradeMeansUnavailable() {
        baseProgram();
        long other = user("ots-2@bingol.edu.tr", "Olmayan Bölüm", "1");
        long noGrade = user("ots-3@bingol.edu.tr", DEPT, null);
        long noDept = user("ots-4@bingol.edu.tr", null, "1");
        for (long u : new long[] {other, noGrade, noDept}) {
            OfficialStatus st = seeder.status(u);
            assertFalse(st.available());
            assertFalse(st.applied());
            assertTrue(st.units().isEmpty());
            assertFalse(seeder.autoSeed(u));
            assertEquals("OFFICIAL_TIMETABLE_NOT_FOUND", assertThrows(ApiException.class,
                    () -> seeder.apply(u, new ApplyRequest(null, null, null))).code());
            assertTrue(tt.timetable(u, null).courses().isEmpty());
        }
        assertEquals(TERM, seeder.status(other).term(), "donem bilgisi yine de doner");
    }

    @Test
    void noOfficialProgramAtAll() {
        OfficialStatus st = seeder.status(uid);
        assertFalse(st.available());
        assertNull(st.term());
        assertFalse(seeder.autoSeed(uid));
    }

    @Test
    void departmentMatchIsTurkishAwareAndPurgerClearsMarker() {
        long u = user("ots-5@bingol.edu.tr", "İşletme", "1");
        off(TERM, MYO, "ISLETME", "1", null, 1, "08:15", "10:00", null, "Muhasebe", null);
        assertTrue(seeder.autoSeed(u));
        assertEquals(1, tt.timetable(u, null).courses().size());
        new AcademicAccountPurger(jdbc).purge(u);
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM tt_official_seed WHERE user_id = ?", Integer.class, u));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM tt_course WHERE user_id = ?", Integer.class, u));
    }

    @Test
    void courseLimitTruncatesAutoSeed() {
        for (int i = 0; i < TimetableService.MAX_COURSES + 5; i++) {
            off(TERM, MYO, DEPT, "1", null, 1 + i % 5, "08:15", "10:00", null, "Ders " + i, null);
        }
        assertTrue(seeder.autoSeed(uid));
        assertEquals(TimetableService.MAX_COURSES, tt.timetable(uid, null).courses().size());
    }
}
