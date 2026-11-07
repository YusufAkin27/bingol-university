package edu.bingol.backend.academic;

import static edu.bingol.backend.academic.AcademicSupport.insert;
import static edu.bingol.backend.academic.AcademicSupport.notFound;
import static edu.bingol.backend.academic.AcademicSupport.optText;
import static edu.bingol.backend.academic.AcademicSupport.reqText;

import edu.bingol.backend.academic.AcademicDtos.ExamRequest;
import edu.bingol.backend.academic.AcademicDtos.ExamView;
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

/** Kisisel sinavlar (tt_exam): kullanicinin kendi sinavlari. */
@Service
public class ExamService {

    static final Set<String> TYPES = Set.of("VIZE", "FINAL", "BUT", "QUIZ", "ODEV", "DIGER");
    private static final int MAX_EXAMS = 300;

    private final JdbcTemplate jdbc;
    private final Clock clock;
    private ContentGuard guard;

    @Autowired
    public ExamService(JdbcTemplate jdbc) {
        this(jdbc, Clock.systemUTC());
    }

    ExamService(JdbcTemplate jdbc, Clock clock) {
        this.jdbc = jdbc;
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

    LocalDate today() {
        return LocalDate.ofInstant(clock.instant(), AcademicTime.ZONE);
    }
}
