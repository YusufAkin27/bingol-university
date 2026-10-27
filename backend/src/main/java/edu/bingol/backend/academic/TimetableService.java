package edu.bingol.backend.academic;

import static edu.bingol.backend.academic.AcademicSupport.insert;
import static edu.bingol.backend.academic.AcademicSupport.notFound;
import static edu.bingol.backend.academic.AcademicSupport.optText;
import static edu.bingol.backend.academic.AcademicSupport.placeholders;
import static edu.bingol.backend.academic.AcademicSupport.reqText;

import edu.bingol.backend.academic.AcademicDtos.CourseRequest;
import edu.bingol.backend.academic.AcademicDtos.CourseView;
import edu.bingol.backend.academic.AcademicDtos.DayItem;
import edu.bingol.backend.academic.AcademicDtos.ExamView;
import edu.bingol.backend.academic.AcademicDtos.ImportRequest;
import edu.bingol.backend.academic.AcademicDtos.ImportResult;
import edu.bingol.backend.academic.AcademicDtos.NextItem;
import edu.bingol.backend.academic.AcademicDtos.OfficialSemester;
import edu.bingol.backend.academic.AcademicDtos.ReminderSession;
import edu.bingol.backend.academic.AcademicDtos.RemindersView;
import edu.bingol.backend.academic.AcademicDtos.SemesterRequest;
import edu.bingol.backend.academic.AcademicDtos.SemesterView;
import edu.bingol.backend.academic.AcademicDtos.SemestersView;
import edu.bingol.backend.academic.AcademicDtos.SessionIn;
import edu.bingol.backend.academic.AcademicDtos.SessionView;
import edu.bingol.backend.academic.AcademicDtos.TimetableView;
import edu.bingol.backend.academic.AcademicDtos.TodayView;
import edu.bingol.backend.academic.AcademicDtos.WeekDay;
import edu.bingol.backend.academic.AcademicDtos.WeekView;
import edu.bingol.backend.academic.TimetableLogic.Entry;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import java.sql.Date;
import java.sql.Time;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZonedDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Kisisel ders programi: donemler, dersler + oturumlar, bugun/hafta gorunumu, hatirlatma listesi, .ics. */
@Service
public class TimetableService {

    static final int MAX_COURSES = 40;
    static final int MAX_SESSIONS_PER_COURSE = 12;
    static final int MAX_SEMESTERS = 8;
    static final int MAX_IMPORT_SESSIONS = 60;

    private final JdbcTemplate jdbc;
    private final ExamService exams;
    private final Clock clock;
    private ContentGuard guard;

    @Autowired
    public TimetableService(JdbcTemplate jdbc, ExamService exams) {
        this(jdbc, exams, Clock.systemUTC());
    }

    TimetableService(JdbcTemplate jdbc, ExamService exams, Clock clock) {
        this.jdbc = jdbc;
        this.exams = exams;
        this.clock = clock;
    }

    @Autowired(required = false)
    void setGuard(ContentGuard guard) {
        this.guard = guard;
    }

    private LocalDate today() {
        return LocalDate.ofInstant(clock.instant(), AcademicTime.ZONE);
    }

    // =================== donemler ===================

    private SemesterView semesterOf(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new SemesterView(rs.getLong("id"), rs.getString("name"), rs.getDate("start_date").toLocalDate().toString(),
                rs.getDate("end_date").toLocalDate().toString(), rs.getBoolean("is_current"));
    }

    private static final String SEM_SELECT = "SELECT id, name, start_date, end_date, is_current FROM tt_semester ";

    public SemestersView semesters(Long uid) {
        List<SemesterView> items = jdbc.query(SEM_SELECT + "WHERE user_id = ? ORDER BY start_date DESC, id DESC",
                (rs, i) -> semesterOf(rs), uid);
        return new SemestersView(items, officialCurrent());
    }

    private SemesterView ownedSemester(Long uid, Long id) {
        List<SemesterView> r = jdbc.query(SEM_SELECT + "WHERE id = ? AND user_id = ?", (rs, i) -> semesterOf(rs), id, uid);
        if (r.isEmpty()) {
            throw notFound("SEMESTER_NOT_FOUND", "Dönem bulunamadı.");
        }
        return r.get(0);
    }

    private SemesterView currentSemester(Long uid) {
        List<SemesterView> r = jdbc.query(SEM_SELECT + "WHERE user_id = ? AND is_current = TRUE ORDER BY id DESC",
                (rs, i) -> semesterOf(rs), uid);
        return r.isEmpty() ? null : r.get(0);
    }

    /** Resmi takvimde (yayinda DONEM_BASLANGIC) bugunu kapsayan ya da en yakin gelecek donem. */
    OfficialSemester officialCurrent() {
        LocalDate today = today();
        record Row(String title, LocalDate start, LocalDate end) {}
        List<Row> rows = jdbc.query("SELECT title, starts_at, ends_at FROM academic_event WHERE kind = 'DONEM_BASLANGIC' "
                + "AND published = TRUE AND scope_department IS NULL ORDER BY starts_at", (rs, i) -> {
            LocalDate s = LocalDate.ofInstant(rs.getTimestamp("starts_at").toInstant(), AcademicTime.ZONE);
            Timestamp e = rs.getTimestamp("ends_at");
            LocalDate end = e == null ? s.plusWeeks(16) : LocalDate.ofInstant(e.toInstant(), AcademicTime.ZONE);
            return new Row(rs.getString("title"), s, end);
        });
        Row pick = null;
        for (Row r : rows) {
            if (!today.isBefore(r.start()) && !today.isAfter(r.end())) {
                pick = r;
                break;
            }
            if (r.start().isAfter(today)) {
                pick = r;
                break;
            }
        }
        return pick == null ? null : new OfficialSemester(pick.title(), pick.start().toString(), pick.end().toString());
    }

    @Transactional
    public SemesterView createSemester(Long uid, SemesterRequest r) {
        String name = reqText(r.name(), 60, "name");
        LocalDate start = AcademicTime.parseDate(r.startDate());
        LocalDate end = AcademicTime.parseDate(r.endDate());
        ContentGuard.clean(guard, Entity.OTHER, "name", uid, name);
        return insertSemester(uid, name, start, end, Boolean.TRUE.equals(r.current()));
    }

    private SemesterView insertSemester(Long uid, String name, LocalDate start, LocalDate end, boolean makeCurrent) {
        if (!end.isAfter(start)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "SEMESTER_INVALID", "Bitiş tarihi başlangıçtan sonra olmalı.");
        }
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM tt_semester WHERE user_id = ?", Long.class, uid);
        long count = n == null ? 0 : n;
        if (count >= MAX_SEMESTERS) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "SEMESTER_LIMIT", "En çok {0} dönem eklenebilir.",
                    String.valueOf(MAX_SEMESTERS));
        }
        boolean cur = makeCurrent || count == 0;
        if (cur) {
            jdbc.update("UPDATE tt_semester SET is_current = FALSE WHERE user_id = ?", uid);
        }
        long id = insert(jdbc, "INSERT INTO tt_semester (user_id, name, start_date, end_date, is_current) VALUES (?, ?, ?, ?, ?)",
                uid, name, Date.valueOf(start), Date.valueOf(end), cur);
        return ownedSemester(uid, id);
    }

    @Transactional
    public SemesterView semesterFromOfficial(Long uid) {
        OfficialSemester o = officialCurrent();
        if (o == null) {
            throw notFound("NO_OFFICIAL_SEMESTER", "Resmi dönem tanımlı değil.");
        }
        return insertSemester(uid, o.name().length() > 60 ? o.name().substring(0, 60) : o.name(),
                LocalDate.parse(o.startDate()), LocalDate.parse(o.endDate()), true);
    }

    @Transactional
    public SemesterView updateSemester(Long uid, Long id, SemesterRequest r) {
        SemesterView cur = ownedSemester(uid, id);
        String name = r.name() != null ? reqText(r.name(), 60, "name") : cur.name();
        LocalDate start = r.startDate() != null ? AcademicTime.parseDate(r.startDate()) : LocalDate.parse(cur.startDate());
        LocalDate end = r.endDate() != null ? AcademicTime.parseDate(r.endDate()) : LocalDate.parse(cur.endDate());
        if (!end.isAfter(start)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "SEMESTER_INVALID", "Bitiş tarihi başlangıçtan sonra olmalı.");
        }
        ContentGuard.changed(guard, Entity.OTHER, "name", uid, cur.name(), name);
        boolean makeCurrent = Boolean.TRUE.equals(r.current());
        if (makeCurrent) {
            jdbc.update("UPDATE tt_semester SET is_current = FALSE WHERE user_id = ?", uid);
        }
        jdbc.update("UPDATE tt_semester SET name = ?, start_date = ?, end_date = ?, is_current = ? WHERE id = ? AND user_id = ?",
                name, Date.valueOf(start), Date.valueOf(end), makeCurrent || (cur.current() && !Boolean.FALSE.equals(r.current())), id, uid);
        return ownedSemester(uid, id);
    }

    @Transactional
    public void deleteSemester(Long uid, Long id) {
        ownedSemester(uid, id);
        jdbc.update("UPDATE tt_course SET semester_id = NULL WHERE semester_id = ? AND user_id = ?", id, uid);
        jdbc.update("DELETE FROM tt_semester WHERE id = ? AND user_id = ?", id, uid);
    }

    // =================== dersler ===================

    /** Ayristirilmis oturum. */
    record Parsed(int day, LocalTime start, LocalTime end, String room) {}

    private record CourseRow(long id, String name, String code, String instructor, String color, String note, Long semesterId) {}

    private List<CourseView> views(String where, Object... args) {
        List<CourseRow> rows = jdbc.query("SELECT id, name, code, instructor, color, note, semester_id FROM tt_course "
                + where + " ORDER BY name, id", (rs, i) -> new CourseRow(rs.getLong("id"), rs.getString("name"),
                rs.getString("code"), rs.getString("instructor"), rs.getString("color"), rs.getString("note"),
                rs.getObject("semester_id") == null ? null : rs.getLong("semester_id")), args);
        if (rows.isEmpty()) {
            return List.of();
        }
        List<Long> ids = rows.stream().map(CourseRow::id).toList();
        Map<Long, List<SessionView>> sessions = new LinkedHashMap<>();
        jdbc.query("SELECT id, course_id, day_of_week, start_time, end_time, room FROM tt_session WHERE course_id IN ("
                + placeholders(ids) + ") ORDER BY day_of_week, start_time, id", rs -> {
            sessions.computeIfAbsent(rs.getLong("course_id"), k -> new ArrayList<>()).add(new SessionView(rs.getLong("id"),
                    rs.getInt("day_of_week"), AcademicTime.fmtTime(rs.getTime("start_time").toLocalTime()),
                    AcademicTime.fmtTime(rs.getTime("end_time").toLocalTime()), rs.getString("room")));
        }, ids.toArray());
        return rows.stream().map(c -> new CourseView(c.id(), c.name(), c.code(), c.instructor(), c.color(), c.note(),
                c.semesterId(), sessions.getOrDefault(c.id(), List.of()))).toList();
    }

    private CourseView ownedCourse(Long uid, Long id) {
        List<CourseView> r = views("WHERE id = ? AND user_id = ?", id, uid);
        if (r.isEmpty()) {
            throw notFound("COURSE_NOT_FOUND", "Ders bulunamadı.");
        }
        return r.get(0);
    }

    public TimetableView timetable(Long uid, Long semesterId) {
        if (semesterId != null) {
            SemesterView s = ownedSemester(uid, semesterId);
            return new TimetableView(s, views("WHERE user_id = ? AND semester_id = ?", uid, semesterId));
        }
        SemesterView cur = currentSemester(uid);
        if (cur == null) {
            return new TimetableView(null, views("WHERE user_id = ?", uid));
        }
        return new TimetableView(cur, views("WHERE user_id = ? AND (semester_id = ? OR semester_id IS NULL)", uid, cur.id()));
    }

    @Transactional
    public CourseView createCourse(Long uid, CourseRequest r) {
        long count = countCourses(uid);
        if (count >= MAX_COURSES) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_LIMIT", "En çok {0} ders eklenebilir.",
                    String.valueOf(MAX_COURSES));
        }
        Long semId = resolveSemester(uid, r.semesterId(), true);
        long id = createOne(uid, r, semId, Boolean.TRUE.equals(r.force()), null);
        return ownedCourse(uid, id);
    }

    private long countCourses(Long uid) {
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM tt_course WHERE user_id = ?", Long.class, uid);
        return n == null ? 0 : n;
    }

    /** semesterId verilmisse sahipligi dogrular; verilmediyse (useCurrent) guncel donem ya da null. */
    private Long resolveSemester(Long uid, Long semesterId, boolean useCurrent) {
        if (semesterId != null) {
            return ownedSemester(uid, semesterId).id();
        }
        if (!useCurrent) {
            return null;
        }
        SemesterView cur = currentSemester(uid);
        return cur == null ? null : cur.id();
    }

    /** Dogrular, cakisma denetler, dersi ve oturumlarini yazar. `extra`: ayni istekteki onceki (henuz yazilmamis) girdiler. */
    private long createOne(Long uid, CourseRequest r, Long semId, boolean force, List<Entry> extra) {
        String name = reqText(r.name(), 120, "name");
        String code = optText(r.code(), 20, "code");
        String instructor = optText(r.instructor(), 120, "instructor");
        String note = optText(r.note(), 500, "note");
        String color = TimetableLogic.resolveColor(r.color(), name);
        if (color == null) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_COLOR_INVALID", "Renk anahtarı geçersiz.");
        }
        ContentGuard.clean(guard, Entity.OTHER, "name", uid, name);
        ContentGuard.clean(guard, Entity.OTHER, "instructor", uid, instructor);
        ContentGuard.clean(guard, Entity.OTHER, "note", uid, note);
        List<Parsed> sessions = parseSessions(r, true);
        if (!force) {
            checkConflict(uid, semId, null, name, sessions, extra);
        }
        long id = insert(jdbc, "INSERT INTO tt_course (user_id, semester_id, name, code, instructor, color, note) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?)", uid, semId, name, code, instructor, color, note);
        insertSessions(id, sessions);
        return id;
    }

    private void insertSessions(long courseId, List<Parsed> sessions) {
        for (Parsed p : sessions) {
            jdbc.update("INSERT INTO tt_session (course_id, day_of_week, start_time, end_time, room) VALUES (?, ?, ?, ?, ?)",
                    courseId, p.day(), Time.valueOf(p.start()), Time.valueOf(p.end()), p.room());
        }
    }

    /** Istek govdesinden oturumlari cikarir (sessions[] ya da kok alanlar). */
    List<Parsed> parseSessions(CourseRequest r, boolean required) {
        List<SessionIn> in = new ArrayList<>();
        if (r.sessions() != null && !r.sessions().isEmpty()) {
            in.addAll(r.sessions());
        } else if (r.sessions() == null && (r.dayOfWeek() != null || r.startTime() != null || r.endTime() != null)) {
            in.add(new SessionIn(r.dayOfWeek(), r.startTime(), r.endTime(), r.room()));
        }
        if (in.isEmpty()) {
            if (required || r.sessions() != null) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_SESSIONS_REQUIRED", "En az bir ders saati gerekli.");
            }
            return List.of();
        }
        if (in.size() > MAX_SESSIONS_PER_COURSE) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "SESSION_LIMIT", "Bir derse en çok {0} oturum eklenebilir.",
                    String.valueOf(MAX_SESSIONS_PER_COURSE));
        }
        List<Parsed> out = new ArrayList<>();
        for (SessionIn s : in) {
            if (s == null || !TimetableLogic.validDay(s.dayOfWeek())) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_INVALID_DAY", "Gün 1 (Pazartesi) ile 7 (Pazar) arasında olmalı.");
            }
            LocalTime st = AcademicTime.parseTime(s.start());
            LocalTime en = AcademicTime.parseTime(s.end());
            if (!en.isAfter(st)) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_INVALID_TIME", "Bitiş saati başlangıçtan sonra olmalı.");
            }
            out.add(new Parsed(s.dayOfWeek(), st, en, optText(s.room(), 60, "room")));
        }
        return out;
    }

    private void checkConflict(Long uid, Long semId, Long excludeCourse, String name, List<Parsed> sessions, List<Entry> extra) {
        List<Entry> existing = new ArrayList<>();
        String where = "SELECT c.id, c.name, s.day_of_week, s.start_time, s.end_time FROM tt_course c JOIN tt_session s ON s.course_id = c.id "
                + "WHERE c.user_id = ? AND " + (semId == null ? "c.semester_id IS NULL" : "c.semester_id = ?");
        Object[] args = semId == null ? new Object[] {uid} : new Object[] {uid, semId};
        jdbc.query(where, rs -> {
            long cid = rs.getLong("id");
            if (excludeCourse == null || cid != excludeCourse) {
                existing.add(new Entry(cid, rs.getString("name"), rs.getInt("day_of_week"),
                        rs.getTime("start_time").toLocalTime(), rs.getTime("end_time").toLocalTime()));
            }
        }, args);
        if (extra != null) {
            existing.addAll(extra);
        }
        List<Entry> incoming = sessions.stream().map(p -> new Entry(null, name, p.day(), p.start(), p.end())).toList();
        Entry c = TimetableLogic.firstConflict(existing, incoming);
        if (c != null) {
            throw new ApiException(HttpStatus.CONFLICT, "COURSE_CONFLICT", "Ders saati çakışıyor: {0}",
                    TimetableLogic.describe(c));
        }
    }

    @Transactional
    public CourseView updateCourse(Long uid, Long id, CourseRequest r) {
        CourseView cur = ownedCourse(uid, id);
        String name = r.name() != null ? reqText(r.name(), 120, "name") : cur.name();
        String code = r.code() != null ? optText(r.code(), 20, "code") : cur.code();
        String instructor = r.instructor() != null ? optText(r.instructor(), 120, "instructor") : cur.instructor();
        String note = r.note() != null ? optText(r.note(), 500, "note") : cur.note();
        String color = r.color() != null ? TimetableLogic.resolveColor(r.color(), name) : cur.color();
        if (color == null) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_COLOR_INVALID", "Renk anahtarı geçersiz.");
        }
        ContentGuard.changed(guard, Entity.OTHER, "name", uid, cur.name(), name);
        ContentGuard.changed(guard, Entity.OTHER, "instructor", uid, cur.instructor(), instructor);
        ContentGuard.changed(guard, Entity.OTHER, "note", uid, cur.note(), note);
        Long semId = r.semesterId() != null ? resolveSemester(uid, r.semesterId(), false) : cur.semesterId();
        List<Parsed> sessions = parseSessions(r, false);
        boolean replaceSessions = !sessions.isEmpty();
        boolean semChanged = !java.util.Objects.equals(semId, cur.semesterId());
        if ((replaceSessions || semChanged) && !Boolean.TRUE.equals(r.force())) {
            List<Parsed> toCheck = replaceSessions ? sessions : cur.sessions().stream()
                    .map(s -> new Parsed(s.dayOfWeek(), LocalTime.parse(s.start()), LocalTime.parse(s.end()), s.room())).toList();
            checkConflict(uid, semId, id, name, toCheck, null);
        }
        jdbc.update("UPDATE tt_course SET name = ?, code = ?, instructor = ?, color = ?, note = ?, semester_id = ? "
                + "WHERE id = ? AND user_id = ?", name, code, instructor, color, note, semId, id, uid);
        if (replaceSessions) {
            jdbc.update("DELETE FROM tt_session WHERE course_id = ?", id);
            insertSessions(id, sessions);
        }
        return ownedCourse(uid, id);
    }

    @Transactional
    public void deleteCourse(Long uid, Long id) {
        ownedCourse(uid, id);
        jdbc.update("UPDATE tt_exam SET course_id = NULL WHERE course_id = ? AND user_id = ?", id, uid);
        jdbc.update("DELETE FROM tt_session WHERE course_id = ?", id);
        jdbc.update("DELETE FROM tt_course WHERE id = ? AND user_id = ?", id, uid);
    }

    @Transactional
    public ImportResult importCourses(Long uid, ImportRequest r) {
        List<CourseRequest> list = r.courses() == null ? List.of() : r.courses();
        if (list.isEmpty()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_SESSIONS_REQUIRED", "En az bir ders gerekli.");
        }
        int total = 0;
        for (CourseRequest c : list) {
            List<Parsed> p = parseSessions(c, true);
            total += p.size();
        }
        if (total > MAX_IMPORT_SESSIONS) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "IMPORT_TOO_LARGE", "En çok {0} oturum içe aktarılabilir.",
                    String.valueOf(MAX_IMPORT_SESSIONS));
        }
        Long semId = resolveSemester(uid, r.semesterId(), true);
        boolean force = Boolean.TRUE.equals(r.force());
        if (Boolean.TRUE.equals(r.replace())) {
            List<Long> old = jdbc.queryForList("SELECT id FROM tt_course WHERE user_id = ? AND "
                    + (semId == null ? "semester_id IS NULL" : "semester_id = ?"), Long.class,
                    semId == null ? new Object[] {uid} : new Object[] {uid, semId});
            for (Long cid : old) {
                deleteCourse(uid, cid);
            }
        }
        if (countCourses(uid) + list.size() > MAX_COURSES) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_LIMIT", "En çok {0} ders eklenebilir.",
                    String.valueOf(MAX_COURSES));
        }
        List<Long> ids = new ArrayList<>();
        for (CourseRequest c : list) {
            ids.add(createOne(uid, c, semId, force, null));
        }
        // createOne her dersi yazdigi icin sonraki dersler onceki yazilanlarla da (veritabani uzerinden) cakisma denetler
        return new ImportResult(ids.size(), ids.stream().map(id -> ownedCourse(uid, id)).toList());
    }

    // =================== gorunumler ===================

    /** Bir tarihe dusen oturum (dersin donem sinirlari gozetilmis). */
    private record Occ(long courseId, long sessionId, String name, String code, String instructor, String room,
                       String color, int day, LocalTime start, LocalTime end, LocalDate semStart, LocalDate semEnd,
                       boolean semCurrent) {}

    private List<Occ> occurrences(Long uid) {
        return jdbc.query("SELECT c.id AS cid, c.name, c.code, c.instructor, c.color, s.id AS sid, s.day_of_week, s.start_time, "
                + "s.end_time, s.room, sem.start_date, sem.end_date, sem.is_current "
                + "FROM tt_course c JOIN tt_session s ON s.course_id = c.id LEFT JOIN tt_semester sem ON sem.id = c.semester_id "
                + "WHERE c.user_id = ?", (rs, i) -> {
            Date sd = rs.getDate("start_date");
            Date ed = rs.getDate("end_date");
            return new Occ(rs.getLong("cid"), rs.getLong("sid"), rs.getString("name"), rs.getString("code"),
                    rs.getString("instructor"), rs.getString("room"), rs.getString("color"), rs.getInt("day_of_week"),
                    rs.getTime("start_time").toLocalTime(), rs.getTime("end_time").toLocalTime(),
                    sd == null ? null : sd.toLocalDate(), ed == null ? null : ed.toLocalDate(), rs.getBoolean("is_current"));
        }, uid);
    }

    private boolean hasCurrentSemester(Long uid) {
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM tt_semester WHERE user_id = ? AND is_current = TRUE", Long.class, uid);
        return n != null && n > 0;
    }

    private static boolean activeOn(Occ o, LocalDate date, boolean hasCurrent) {
        if (o.semStart() == null) {
            return true;
        }
        if (hasCurrent && !o.semCurrent()) {
            return false;
        }
        return !date.isBefore(o.semStart()) && !date.isAfter(o.semEnd());
    }

    private static List<Occ> on(List<Occ> all, LocalDate date, boolean hasCurrent) {
        return all.stream().filter(o -> o.day() == date.getDayOfWeek().getValue() && activeOn(o, date, hasCurrent))
                .sorted(Comparator.comparing(Occ::start).thenComparing(Occ::end)).toList();
    }

    private DayItem item(Occ o, String status) {
        return new DayItem(o.courseId(), o.sessionId(), o.name(), o.code(), o.instructor(), o.room(), o.color(),
                AcademicTime.fmtTime(o.start()), AcademicTime.fmtTime(o.end()), status);
    }

    private String status(Occ o, LocalDate date, ZonedDateTime now) {
        LocalDate t = now.toLocalDate();
        if (date.isBefore(t)) {
            return "PAST";
        }
        if (date.isAfter(t)) {
            return "UPCOMING";
        }
        LocalTime nt = now.toLocalTime();
        if (!nt.isBefore(o.end())) {
            return "PAST";
        }
        return nt.isBefore(o.start()) ? "UPCOMING" : "ONGOING";
    }

    public TodayView today(Long uid, String dateStr) {
        ZonedDateTime now = clock.instant().atZone(AcademicTime.ZONE);
        LocalDate date = dateStr == null || dateStr.isBlank() ? now.toLocalDate() : AcademicTime.parseDate(dateStr);
        List<Occ> all = occurrences(uid);
        boolean hc = hasCurrentSemester(uid);
        List<DayItem> items = on(all, date, hc).stream().map(o -> item(o, status(o, date, now))).toList();
        return new TodayView(date.toString(), date.getDayOfWeek().getValue(), items, next(all, hc, now));
    }

    private NextItem next(List<Occ> all, boolean hc, ZonedDateTime now) {
        for (int d = 0; d <= 7; d++) {
            LocalDate date = now.toLocalDate().plusDays(d);
            for (Occ o : on(all, date, hc)) {
                ZonedDateTime st = date.atTime(o.start()).atZone(AcademicTime.ZONE);
                if (st.isAfter(now)) {
                    return new NextItem(date.toString(), o.courseId(), o.sessionId(), o.name(),
                            AcademicTime.fmtTime(o.start()), AcademicTime.fmtTime(o.end()), o.room(), o.color(),
                            Duration.between(now, st).toMinutes());
                }
            }
        }
        return null;
    }

    public WeekView week(Long uid, String dateStr) {
        ZonedDateTime now = clock.instant().atZone(AcademicTime.ZONE);
        LocalDate date = dateStr == null || dateStr.isBlank() ? now.toLocalDate() : AcademicTime.parseDate(dateStr);
        LocalDate monday = date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        List<Occ> all = occurrences(uid);
        boolean hc = hasCurrentSemester(uid);
        List<WeekDay> days = new ArrayList<>();
        for (int i = 0; i < 7; i++) {
            LocalDate d = monday.plusDays(i);
            days.add(new WeekDay(i + 1, d.toString(), on(all, d, hc).stream().map(o -> item(o, status(o, d, now))).toList()));
        }
        return new WeekView(monday.toString(), days);
    }

    public RemindersView reminders(Long uid, int days) {
        int n = Math.min(Math.max(days, 1), 14);
        Instant nowI = clock.instant();
        ZonedDateTime now = nowI.atZone(AcademicTime.ZONE);
        Instant limit = nowI.plusSeconds(n * 86400L);
        List<Occ> all = occurrences(uid);
        boolean hc = hasCurrentSemester(uid);
        List<ReminderSession> out = new ArrayList<>();
        for (int d = 0; d <= n; d++) {
            LocalDate date = now.toLocalDate().plusDays(d);
            for (Occ o : on(all, date, hc)) {
                ZonedDateTime st = date.atTime(o.start()).atZone(AcademicTime.ZONE);
                if (st.toInstant().isAfter(nowI) && !st.toInstant().isAfter(limit)) {
                    out.add(new ReminderSession(o.courseId(), o.sessionId(), o.name(), o.room(),
                            AcademicTime.fmt(st.toInstant()), AcademicTime.fmt(date.atTime(o.end()).atZone(AcademicTime.ZONE).toInstant())));
                }
            }
        }
        out.sort(Comparator.comparing(ReminderSession::startsAt));
        List<ExamView> ex = exams.upcoming(uid, n);
        return new RemindersView(AcademicTime.fmt(nowI), out, ex);
    }

    /** KVKK disa aktarim: tum donemler, dersler (oturumlariyla) ve sinavlar. */
    public Map<String, Object> exportData(Long uid) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("semesters", semesters(uid).items());
        out.put("courses", views("WHERE user_id = ?", uid));
        out.put("exams", exams.list(uid, null, null));
        return out;
    }

    public String exportIcs(Long uid, Long semesterId) {
        TimetableView t = timetable(uid, semesterId);
        List<IcsBuilder.SessionEvent> evs = new ArrayList<>();
        for (CourseView c : t.courses()) {
            for (SessionView s : c.sessions()) {
                evs.add(new IcsBuilder.SessionEvent(s.id(), c.name(), c.code(), c.instructor(), s.room(), s.dayOfWeek(),
                        LocalTime.parse(s.start()), LocalTime.parse(s.end())));
            }
        }
        List<IcsBuilder.ExamEvent> exs = new ArrayList<>();
        for (ExamView e : exams.upcoming(uid, 365)) {
            exs.add(new IcsBuilder.ExamEvent(e.id(), e.title(), e.courseName(), e.room(),
                    AcademicTime.parseInstant(e.startsAt()), e.endsAt() == null ? null : AcademicTime.parseInstant(e.endsAt())));
        }
        LocalDate ss = t.semester() == null ? null : LocalDate.parse(t.semester().startDate());
        LocalDate se = t.semester() == null ? null : LocalDate.parse(t.semester().endDate());
        return IcsBuilder.build(evs, exs, ss, se, today(), clock.instant());
    }
}
