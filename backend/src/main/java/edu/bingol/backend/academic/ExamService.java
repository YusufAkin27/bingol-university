package edu.bingol.backend.academic;

import static edu.bingol.backend.academic.AcademicSupport.adminText;
import static edu.bingol.backend.academic.AcademicSupport.insert;
import static edu.bingol.backend.academic.AcademicSupport.notFound;
import static edu.bingol.backend.academic.AcademicSupport.optText;
import static edu.bingol.backend.academic.AcademicSupport.reqText;

import edu.bingol.backend.academic.AcademicDtos.AdminExamScheduleView;
import edu.bingol.backend.academic.AcademicDtos.ExamRequest;
import edu.bingol.backend.academic.AcademicDtos.ExamScheduleRequest;
import edu.bingol.backend.academic.AcademicDtos.ExamView;
import edu.bingol.backend.academic.AcademicDtos.OfficialExamView;
import edu.bingol.backend.academic.AcademicDtos.OfficialExamsView;
import edu.bingol.backend.academic.AcademicDtos.Page;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Kisisel sinavlar (tt_exam), resmi sinav programi okuma (exam_schedule) ve yonetici CRUD'u. */
@Service
public class ExamService {

    static final Set<String> TYPES = Set.of("VIZE", "FINAL", "BUT", "QUIZ", "ODEV", "DIGER");
    private static final int MAX_EXAMS = 300;

    private final JdbcTemplate jdbc;
    private final AcademicAudience audience;
    private final Clock clock;
    private ContentGuard guard;

    @Autowired
    public ExamService(JdbcTemplate jdbc, AcademicAudience audience) {
        this(jdbc, audience, Clock.systemUTC());
    }

    ExamService(JdbcTemplate jdbc, AcademicAudience audience, Clock clock) {
        this.jdbc = jdbc;
        this.audience = audience;
        this.clock = clock;
    }

    @Autowired(required = false)
    void setGuard(ContentGuard guard) {
        this.guard = guard;
    }

    private static final RowMapper<ExamView> EXAM = (rs, i) -> new ExamView(rs.getLong("id"),
            rs.getObject("course_id") == null ? null : rs.getLong("course_id"), rs.getString("cname"),
            rs.getString("title"), rs.getString("type"), AcademicTime.fmt(rs.getTimestamp("starts_at")),
            AcademicTime.fmt(rs.getTimestamp("ends_at")), rs.getString("room"), rs.getString("note"));

    private static final String EXAM_SELECT = "SELECT e.id, e.course_id, c.name AS cname, e.title, e.type, e.starts_at, "
            + "e.ends_at, e.room, e.note FROM tt_exam e LEFT JOIN tt_course c ON c.id = e.course_id ";

    // ---- kisisel sinavlar ----

    public List<ExamView> list(Long uid, String from, String to) {
        StringBuilder sql = new StringBuilder(EXAM_SELECT).append("WHERE e.user_id = ?");
        List<Object> args = new ArrayList<>(List.of(uid));
        if (from != null && !from.isBlank()) {
            sql.append(" AND e.starts_at >= ?");
            args.add(Timestamp.from(AcademicTime.startOfDay(AcademicTime.parseDate(from))));
        }
        if (to != null && !to.isBlank()) {
            sql.append(" AND e.starts_at < ?");
            args.add(Timestamp.from(AcademicTime.startOfDay(AcademicTime.parseDate(to).plusDays(1))));
        }
        sql.append(" ORDER BY e.starts_at, e.id");
        return jdbc.query(sql.toString(), EXAM, args.toArray());
    }

    /** Bitmemis sinavlar: bitis (yoksa baslangic + 1 saat) simdiden sonra, `days` gun icinde baslayanlar. */
    public List<ExamView> upcoming(Long uid, int days) {
        int d = Math.min(Math.max(days, 1), 365);
        Instant now = clock.instant();
        return jdbc.query(EXAM_SELECT + "WHERE e.user_id = ? AND e.starts_at >= ? AND e.starts_at <= ? "
                + "ORDER BY e.starts_at, e.id", EXAM, uid,
                Timestamp.from(now.minusSeconds(3600)), Timestamp.from(now.plusSeconds(d * 86400L))).stream()
                .filter(e -> !AcademicTime.parseInstant(e.endsAt() != null ? e.endsAt() : e.startsAt())
                        .plusSeconds(e.endsAt() != null ? 0 : 3600).isBefore(now))
                .toList();
    }

    public ExamView get(Long uid, Long id) {
        List<ExamView> r = jdbc.query(EXAM_SELECT + "WHERE e.id = ? AND e.user_id = ?", EXAM, id, uid);
        if (r.isEmpty()) {
            throw notFound("EXAM_NOT_FOUND", "Sınav bulunamadı.");
        }
        return r.get(0);
    }

    @Transactional
    public ExamView create(Long uid, ExamRequest r) {
        Long count = jdbc.queryForObject("SELECT COUNT(*) FROM tt_exam WHERE user_id = ?", Long.class, uid);
        if (count != null && count >= MAX_EXAMS) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COURSE_LIMIT", "Çok fazla kayıt.", String.valueOf(MAX_EXAMS));
        }
        String title = reqText(r.title(), 120, "title");
        String type = type(r.type());
        Instant starts = AcademicTime.parseInstant(r.startsAt());
        Instant ends = r.endsAt() == null || r.endsAt().isBlank() ? null : AcademicTime.parseInstant(r.endsAt());
        if (ends != null && !ends.isAfter(starts)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "EXAM_INVALID", "{0} geçersiz.", "endsAt");
        }
        String room = optText(r.room(), 60, "room");
        String note = optText(r.note(), 500, "note");
        ContentGuard.clean(guard, Entity.OTHER, "title", uid, title);
        ContentGuard.clean(guard, Entity.OTHER, "note", uid, note);
        checkCourse(uid, r.courseId());
        // Sinav zaten 2 saat icinde (ya da gecmis) girildiyse kullanici bunu biliyor: aninda push gelmesin.
        Timestamp reminded = withinReminderLead(starts) ? Timestamp.from(starts) : null;
        long id = insert(jdbc, "INSERT INTO tt_exam (user_id, course_id, title, type, starts_at, ends_at, room, note, "
                + "reminded_starts_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", uid, r.courseId(), title, type,
                Timestamp.from(starts), ends == null ? null : Timestamp.from(ends), room, note, reminded);
        return get(uid, id);
    }

    @Transactional
    public ExamView update(Long uid, Long id, ExamRequest r) {
        ExamView cur = get(uid, id);
        String title = r.title() != null ? reqText(r.title(), 120, "title") : cur.title();
        String type = r.type() != null ? type(r.type()) : cur.type();
        Instant starts = r.startsAt() != null ? AcademicTime.parseInstant(r.startsAt()) : AcademicTime.parseInstant(cur.startsAt());
        Instant ends = r.endsAt() != null ? (r.endsAt().isBlank() ? null : AcademicTime.parseInstant(r.endsAt()))
                : (cur.endsAt() == null ? null : AcademicTime.parseInstant(cur.endsAt()));
        if (ends != null && !ends.isAfter(starts)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "EXAM_INVALID", "{0} geçersiz.", "endsAt");
        }
        String room = r.room() != null ? optText(r.room(), 60, "room") : cur.room();
        String note = r.note() != null ? optText(r.note(), 500, "note") : cur.note();
        ContentGuard.changed(guard, Entity.OTHER, "title", uid, cur.title(), title);
        ContentGuard.changed(guard, Entity.OTHER, "note", uid, cur.note(), note);
        Long courseId = r.courseId() != null ? r.courseId() : cur.courseId();
        if (r.courseId() != null) {
            checkCourse(uid, r.courseId());
        }
        jdbc.update("UPDATE tt_exam SET course_id = ?, title = ?, type = ?, starts_at = ?, ends_at = ?, room = ?, note = ? "
                + "WHERE id = ? AND user_id = ?", courseId, title, type, Timestamp.from(starts),
                ends == null ? null : Timestamp.from(ends), room, note, id, uid);
        // Saat degistiyse hatirlatma yeniden hak eder (reminded_starts_at artik starts_at'ten farkli); yeni saat zaten
        // 2 saat icindeyse kullanici onu bilerek girmistir, aninda push gonderilmez.
        if (!starts.equals(AcademicTime.parseInstant(cur.startsAt())) && withinReminderLead(starts)) {
            jdbc.update("UPDATE tt_exam SET reminded_starts_at = starts_at WHERE id = ? AND user_id = ?", id, uid);
        }
        return get(uid, id);
    }

    private boolean withinReminderLead(Instant starts) {
        return !starts.isAfter(clock.instant().plus(ExamReminderJob.LEAD));
    }

    @Transactional
    public void delete(Long uid, Long id) {
        if (jdbc.update("DELETE FROM tt_exam WHERE id = ? AND user_id = ?", id, uid) == 0) {
            throw notFound("EXAM_NOT_FOUND", "Sınav bulunamadı.");
        }
    }

    private void checkCourse(Long uid, Long courseId) {
        if (courseId == null) {
            return;
        }
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM tt_course WHERE id = ? AND user_id = ?", Long.class, courseId, uid);
        if (n == null || n == 0) {
            throw notFound("COURSE_NOT_FOUND", "Ders bulunamadı.");
        }
    }

    static String type(String t) {
        String v = t == null ? "" : t.strip().toUpperCase(java.util.Locale.ROOT);
        if (!TYPES.contains(v)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "EXAM_INVALID", "{0} geçersiz.", "type");
        }
        return v;
    }

    // ---- resmi sinav programi (kullanici) ----

    private static final RowMapper<AdminExamScheduleView> SCHEDULE = (rs, i) -> new AdminExamScheduleView(rs.getLong("id"),
            rs.getString("title"), rs.getString("type"), rs.getString("term"), rs.getString("course_code"),
            rs.getString("faculty"), rs.getString("department"), rs.getString("grade"),
            AcademicTime.fmt(rs.getTimestamp("starts_at")), AcademicTime.fmt(rs.getTimestamp("ends_at")),
            rs.getString("room"), rs.getString("note"), rs.getBoolean("published"));

    private static final String SCHEDULE_SELECT = "SELECT id, title, type, term, course_code, faculty, department, grade, "
            + "starts_at, ends_at, room, note, published FROM exam_schedule ";

    public OfficialExamsView official(Long uid, boolean all) {
        AcademicAudience.Who me = audience.of(uid);
        List<AdminExamScheduleView> rows = jdbc.query(SCHEDULE_SELECT + "WHERE published = TRUE ORDER BY starts_at, id", SCHEDULE);
        List<OfficialExamView> items = rows.stream()
                .filter(x -> all || AudienceMatch.matches(x.department(), x.faculty(), x.grade(), me.department(), me.faculty(), me.grade()))
                .limit(500)
                .map(x -> new OfficialExamView(x.id(), x.title(), x.type(), x.term(), x.courseCode(), x.faculty(),
                        x.department(), x.grade(), x.startsAt(), x.endsAt(), x.room(), x.note()))
                .toList();
        return new OfficialExamsView(items, me.complete());
    }

    // ---- yonetici: resmi sinav programi ----

    public Page<AdminExamScheduleView> adminList(int page, int size, String q) {
        int p = Math.max(page, 0);
        int s = Math.min(Math.max(size, 1), 100);
        String like = q == null || q.isBlank() ? null : "%" + q.strip().toLowerCase(java.util.Locale.ROOT).replace("\\", "\\\\")
                .replace("%", "\\%").replace("_", "\\_") + "%";
        String where = like == null ? "" : "WHERE LOWER(title) LIKE ? ESCAPE '\\' ";
        Object[] a = like == null ? new Object[0] : new Object[] {like};
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM exam_schedule " + where, Long.class, a);
        List<Object> args = new ArrayList<>(List.of(a));
        args.add(s);
        args.add((long) p * s);
        List<AdminExamScheduleView> items = jdbc.query(SCHEDULE_SELECT + where + "ORDER BY starts_at DESC, id DESC LIMIT ? OFFSET ?",
                SCHEDULE, args.toArray());
        return new Page<>(items, p, s, total == null ? 0 : total);
    }

    public AdminExamScheduleView adminGet(Long id) {
        List<AdminExamScheduleView> r = jdbc.query(SCHEDULE_SELECT + "WHERE id = ?", SCHEDULE, id);
        if (r.isEmpty()) {
            throw notFound("EXAM_SCHEDULE_NOT_FOUND", "Sınav programı kaydı bulunamadı.");
        }
        return r.get(0);
    }

    @Transactional
    public AdminExamScheduleView adminCreate(Long adminId, ExamScheduleRequest r) {
        Cols c = scheduleCols(adminId, r, null);
        long id = insert(jdbc, "INSERT INTO exam_schedule (title, type, term, course_code, faculty, department, grade, "
                + "starts_at, ends_at, room, note, published) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                c.title, c.type, c.term, c.courseCode, c.faculty, c.department, c.grade, Timestamp.from(c.starts),
                c.ends == null ? null : Timestamp.from(c.ends), c.room, c.note, c.published);
        return adminGet(id);
    }

    @Transactional
    public AdminExamScheduleView adminUpdate(Long adminId, Long id, ExamScheduleRequest r) {
        Cols c = scheduleCols(adminId, r, adminGet(id));
        jdbc.update("UPDATE exam_schedule SET title = ?, type = ?, term = ?, course_code = ?, faculty = ?, department = ?, "
                + "grade = ?, starts_at = ?, ends_at = ?, room = ?, note = ?, published = ? WHERE id = ?",
                c.title, c.type, c.term, c.courseCode, c.faculty, c.department, c.grade, Timestamp.from(c.starts),
                c.ends == null ? null : Timestamp.from(c.ends), c.room, c.note, c.published, id);
        return adminGet(id);
    }

    @Transactional
    public void adminDelete(Long id) {
        if (jdbc.update("DELETE FROM exam_schedule WHERE id = ?", id) == 0) {
            throw notFound("EXAM_SCHEDULE_NOT_FOUND", "Sınav programı kaydı bulunamadı.");
        }
    }

    @Transactional
    public AdminExamScheduleView adminPublish(Long id, boolean published) {
        adminGet(id);
        jdbc.update("UPDATE exam_schedule SET published = ? WHERE id = ?", published, id);
        return adminGet(id);
    }

    private record Cols(String title, String type, String term, String courseCode, String faculty, String department,
                        String grade, Instant starts, Instant ends, String room, String note, boolean published) {}

    private Cols scheduleCols(Long adminId, ExamScheduleRequest r, AdminExamScheduleView cur) {
        boolean upd = cur != null;
        String title = !upd || r.title() != null ? adminText(r.title(), 150, "title", true, "EXAM_INVALID") : cur.title();
        String type = !upd || r.type() != null ? (r.type() == null ? "FINAL" : type(r.type())) : cur.type();
        String term = !upd || r.term() != null ? adminText(r.term(), 60, "term", true, "EXAM_INVALID") : cur.term();
        String code = !upd || r.courseCode() != null ? adminText(r.courseCode(), 20, "courseCode", false, "EXAM_INVALID") : cur.courseCode();
        String faculty = !upd || r.faculty() != null ? adminText(r.faculty(), 120, "faculty", false, "EXAM_INVALID") : cur.faculty();
        String dept = !upd || r.department() != null ? adminText(r.department(), 120, "department", false, "EXAM_INVALID") : cur.department();
        String grade = !upd || r.grade() != null ? grade(r.grade()) : cur.grade();
        Instant starts = !upd || r.startsAt() != null ? AcademicTime.parseInstant(r.startsAt()) : AcademicTime.parseInstant(cur.startsAt());
        Instant ends = r.endsAt() != null ? (r.endsAt().isBlank() ? null : AcademicTime.parseInstant(r.endsAt()))
                : (upd && cur.endsAt() != null ? AcademicTime.parseInstant(cur.endsAt()) : null);
        if (ends != null && !ends.isAfter(starts)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "EXAM_INVALID", "{0} geçersiz.", "endsAt");
        }
        String room = !upd || r.room() != null ? adminText(r.room(), 60, "room", false, "EXAM_INVALID") : cur.room();
        String note = !upd || r.note() != null ? adminText(r.note(), 500, "note", false, "EXAM_INVALID") : cur.note();
        boolean pub = r.published() != null ? r.published() : (upd && cur.published());
        ContentGuard.clean(guard, Entity.OTHER, "title", adminId, title);
        ContentGuard.clean(guard, Entity.OTHER, "note", adminId, note);
        return new Cols(title, type, term, code, faculty, dept, grade, starts, ends, room, note, pub);
    }

    static final Set<String> GRADES = Set.of("PREP", "1", "2", "3", "4", "5", "6", "MASTER", "PHD");

    static String grade(String g) {
        if (g == null || g.isBlank()) {
            return null;
        }
        String v = g.strip().toUpperCase(java.util.Locale.ROOT);
        if (!GRADES.contains(v)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ANNOUNCEMENT_INVALID", "{0} geçersiz.", "grade");
        }
        return v;
    }

    LocalDate today() {
        return LocalDate.ofInstant(clock.instant(), AcademicTime.ZONE);
    }
}
