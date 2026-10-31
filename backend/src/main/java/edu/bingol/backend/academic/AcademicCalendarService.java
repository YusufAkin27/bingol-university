package edu.bingol.backend.academic;

import static edu.bingol.backend.academic.AcademicSupport.adminText;
import static edu.bingol.backend.academic.AcademicSupport.insert;
import static edu.bingol.backend.academic.AcademicSupport.notFound;

import edu.bingol.backend.academic.AcademicDtos.AcademicEventRequest;
import edu.bingol.backend.academic.AcademicDtos.AcademicEventView;
import edu.bingol.backend.academic.AcademicDtos.AdminAcademicEventView;
import edu.bingol.backend.academic.AcademicDtos.CalendarView;
import edu.bingol.backend.academic.AcademicDtos.EventImportResult;
import edu.bingol.backend.academic.AcademicDtos.ImportError;
import edu.bingol.backend.academic.AcademicDtos.Page;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Resmi akademik takvim: kullanici okuma (bolum kapsamli) ve yonetici CRUD/toplu iceri aktarma. */
@Service
public class AcademicCalendarService {

    static final Set<String> KINDS = Set.of("DONEM_BASLANGIC", "DERS_KAYIT", "VIZE", "FINAL", "BUT", "TATIL", "RESMI_TATIL", "DIGER");
    static final int MAX_RANGE_DAYS = 366;
    static final int MAX_IMPORT_LINES = 200;

    private final JdbcTemplate jdbc;
    private final AcademicAudience audience;
    private final Clock clock;
    private ContentGuard guard;

    @Autowired
    public AcademicCalendarService(JdbcTemplate jdbc, AcademicAudience audience) {
        this(jdbc, audience, Clock.systemUTC());
    }

    AcademicCalendarService(JdbcTemplate jdbc, AcademicAudience audience, Clock clock) {
        this.jdbc = jdbc;
        this.audience = audience;
        this.clock = clock;
    }

    @Autowired(required = false)
    void setGuard(ContentGuard guard) {
        this.guard = guard;
    }

    private static final RowMapper<AdminAcademicEventView> ADMIN_ROW = (rs, i) -> new AdminAcademicEventView(rs.getLong("id"),
            rs.getString("kind"), rs.getString("title"), AcademicTime.fmt(rs.getTimestamp("starts_at")),
            AcademicTime.fmt(rs.getTimestamp("ends_at")), rs.getBoolean("all_day"), rs.getString("scope_department"),
            rs.getString("note"), rs.getBoolean("published"));

    private static final String SELECT = "SELECT id, kind, title, starts_at, ends_at, all_day, scope_department, note, published "
            + "FROM academic_event ";

    private static AcademicEventView pub(AdminAcademicEventView a) {
        return new AcademicEventView(a.id(), a.kind(), a.title(), a.startsAt(), a.endsAt(), a.allDay(), a.scopeDepartment(), a.note());
    }

    // ---- kullanici ----

    /** month=YYYY-MM ya da from/to (tarih, to dahil). */
    public CalendarView calendar(Long uid, String month, String from, String to) {
        LocalDate f;
        LocalDate t;
        if (month != null && !month.isBlank()) {
            try {
                YearMonth ym = YearMonth.parse(month.strip());
                f = ym.atDay(1);
                t = ym.atEndOfMonth();
            } catch (DateTimeParseException e) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "DATE_INVALID", "Tarih geçersiz.");
            }
        } else if (from != null && to != null && !from.isBlank() && !to.isBlank()) {
            f = AcademicTime.parseDate(from);
            t = AcademicTime.parseDate(to);
        } else {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CALENDAR_RANGE_INVALID", "month ya da from/to verilmeli.");
        }
        if (t.isBefore(f) || java.time.temporal.ChronoUnit.DAYS.between(f, t) > MAX_RANGE_DAYS) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CALENDAR_RANGE_INVALID", "Tarih aralığı geçersiz.");
        }
        AcademicAudience.Who me = audience.of(uid);
        StringBuilder sql = new StringBuilder(SELECT).append("WHERE published = TRUE AND starts_at < ? AND COALESCE(ends_at, starts_at) >= ?");
        List<Object> args = new ArrayList<>();
        args.add(Timestamp.from(AcademicTime.startOfDay(t.plusDays(1))));
        args.add(Timestamp.from(AcademicTime.startOfDay(f)));
        scope(sql, args, me);
        sql.append(" ORDER BY starts_at, id");
        List<AcademicEventView> items = jdbc.query(sql.toString(), ADMIN_ROW, args.toArray()).stream().map(AcademicCalendarService::pub).toList();
        return new CalendarView(f.toString(), t.toString(), items);
    }

    public List<AcademicEventView> next(Long uid, int limit) {
        int l = Math.min(Math.max(limit, 1), 20);
        AcademicAudience.Who me = audience.of(uid);
        StringBuilder sql = new StringBuilder(SELECT).append("WHERE published = TRUE AND COALESCE(ends_at, starts_at) >= ?");
        List<Object> args = new ArrayList<>();
        args.add(Timestamp.from(clock.instant()));
        scope(sql, args, me);
        sql.append(" ORDER BY starts_at, id LIMIT ?");
        args.add(l);
        return jdbc.query(sql.toString(), ADMIN_ROW, args.toArray()).stream().map(AcademicCalendarService::pub).toList();
    }

    private static void scope(StringBuilder sql, List<Object> args, AcademicAudience.Who me) {
        if (me.department() == null || me.department().isBlank()) {
            sql.append(" AND scope_department IS NULL");
        } else {
            sql.append(" AND (scope_department IS NULL OR ").append(AudienceKey.sql("scope_department")).append(" = ?)");
            args.add(AudienceKey.of(me.department()));
        }
    }

    // ---- yonetici ----

    public Page<AdminAcademicEventView> adminList(int page, int size, String kind, String q, Boolean published) {
        int p = Math.max(page, 0);
        int s = Math.min(Math.max(size, 1), 100);
        StringBuilder where = new StringBuilder("WHERE 1 = 1");
        List<Object> args = new ArrayList<>();
        if (kind != null && !kind.isBlank()) {
            where.append(" AND kind = ?");
            args.add(kind.strip().toUpperCase(java.util.Locale.ROOT));
        }
        if (q != null && !q.isBlank()) {
            where.append(" AND LOWER(title) LIKE ? ESCAPE '\\'");
            args.add("%" + q.strip().toLowerCase(java.util.Locale.ROOT).replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%");
        }
        if (published != null) {
            where.append(" AND published = ?");
            args.add(published);
        }
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM academic_event " + where, Long.class, args.toArray());
        List<Object> a2 = new ArrayList<>(args);
        a2.add(s);
        a2.add((long) p * s);
        List<AdminAcademicEventView> items = jdbc.query(SELECT + where + " ORDER BY starts_at DESC, id DESC LIMIT ? OFFSET ?",
                ADMIN_ROW, a2.toArray());
        return new Page<>(items, p, s, total == null ? 0 : total);
    }

    public AdminAcademicEventView adminGet(Long id) {
        List<AdminAcademicEventView> r = jdbc.query(SELECT + "WHERE id = ?", ADMIN_ROW, id);
        if (r.isEmpty()) {
            throw notFound("ACADEMIC_EVENT_NOT_FOUND", "Takvim kaydı bulunamadı.");
        }
        return r.get(0);
    }

    /** Yalniz tarih verilen bitis, o gunun 23:59 (Istanbul) anidir. */
    static Instant parseEnd(String s) {
        if (s != null && s.strip().length() == 10) {
            return AcademicTime.parseDate(s).atTime(23, 59).atZone(AcademicTime.ZONE).toInstant();
        }
        return AcademicTime.parseInstant(s);
    }

    static String kind(String k) {
        String v = k == null ? "" : k.strip().toUpperCase(java.util.Locale.ROOT);
        if (!KINDS.contains(v)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ACADEMIC_EVENT_INVALID", "{0} geçersiz.", "kind");
        }
        return v;
    }

    @Transactional
    public AdminAcademicEventView create(Long adminId, AcademicEventRequest r) {
        String kind = kind(r.kind());
        String title = adminText(r.title(), 150, "title", true, "ACADEMIC_EVENT_INVALID");
        Instant starts = AcademicTime.parseInstant(r.startsAt());
        Instant ends = r.endsAt() == null || r.endsAt().isBlank() ? null : parseEnd(r.endsAt());
        if (ends != null && ends.isBefore(starts)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ACADEMIC_EVENT_INVALID", "{0} geçersiz.", "endsAt");
        }
        String dept = adminText(r.scopeDepartment(), 120, "scopeDepartment", false, "ACADEMIC_EVENT_INVALID");
        String note = adminText(r.note(), 500, "note", false, "ACADEMIC_EVENT_INVALID");
        ContentGuard.clean(guard, Entity.ANNOUNCEMENT, "title", adminId, title);
        ContentGuard.clean(guard, Entity.ANNOUNCEMENT, "note", adminId, note);
        long id = insert(jdbc, "INSERT INTO academic_event (kind, title, starts_at, ends_at, all_day, scope_department, note, published) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?)", kind, title, Timestamp.from(starts),
                ends == null ? null : Timestamp.from(ends), r.allDay() == null || r.allDay(), dept, note,
                Boolean.TRUE.equals(r.published()));
        return adminGet(id);
    }

    @Transactional
    public AdminAcademicEventView update(Long adminId, Long id, AcademicEventRequest r) {
        AdminAcademicEventView cur = adminGet(id);
        String kind = r.kind() != null ? kind(r.kind()) : cur.kind();
        String title = r.title() != null ? adminText(r.title(), 150, "title", true, "ACADEMIC_EVENT_INVALID") : cur.title();
        Instant starts = r.startsAt() != null ? AcademicTime.parseInstant(r.startsAt()) : AcademicTime.parseInstant(cur.startsAt());
        Instant ends = r.endsAt() != null ? (r.endsAt().isBlank() ? null : parseEnd(r.endsAt()))
                : (cur.endsAt() == null ? null : AcademicTime.parseInstant(cur.endsAt()));
        if (ends != null && ends.isBefore(starts)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ACADEMIC_EVENT_INVALID", "{0} geçersiz.", "endsAt");
        }
        String dept = r.scopeDepartment() != null ? adminText(r.scopeDepartment(), 120, "scopeDepartment", false, "ACADEMIC_EVENT_INVALID") : cur.scopeDepartment();
        String note = r.note() != null ? adminText(r.note(), 500, "note", false, "ACADEMIC_EVENT_INVALID") : cur.note();
        ContentGuard.changed(guard, Entity.ANNOUNCEMENT, "title", adminId, cur.title(), title);
        ContentGuard.changed(guard, Entity.ANNOUNCEMENT, "note", adminId, cur.note(), note);
        jdbc.update("UPDATE academic_event SET kind = ?, title = ?, starts_at = ?, ends_at = ?, all_day = ?, scope_department = ?, "
                + "note = ?, published = ? WHERE id = ?", kind, title, Timestamp.from(starts),
                ends == null ? null : Timestamp.from(ends), r.allDay() != null ? r.allDay() : cur.allDay(), dept, note,
                r.published() != null ? r.published() : cur.published(), id);
        return adminGet(id);
    }

    @Transactional
    public void delete(Long id) {
        if (jdbc.update("DELETE FROM academic_event WHERE id = ?", id) == 0) {
            throw notFound("ACADEMIC_EVENT_NOT_FOUND", "Takvim kaydı bulunamadı.");
        }
    }

    @Transactional
    public AdminAcademicEventView setPublished(Long id, boolean published) {
        adminGet(id);
        jdbc.update("UPDATE academic_event SET published = ? WHERE id = ?", published, id);
        return adminGet(id);
    }

    /** Satir: KIND;Baslik;baslangic;bitis?;bolum? . Gecerli satirlar yazilir, hatalilar raporlanir. */
    @Transactional
    public EventImportResult importText(Long adminId, String text, boolean publish) {
        List<ImportError> errors = new ArrayList<>();
        int created = 0;
        String[] lines = (text == null ? "" : text).split("\\r?\\n");
        if (lines.length > MAX_IMPORT_LINES + 50) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ACADEMIC_EVENT_INVALID", "{0} geçersiz.", "text");
        }
        int processed = 0;
        for (int i = 0; i < lines.length; i++) {
            String line = lines[i].strip();
            if (line.isEmpty() || line.startsWith("#")) {
                continue;
            }
            if (++processed > MAX_IMPORT_LINES) {
                errors.add(new ImportError(i + 1, "En çok " + MAX_IMPORT_LINES + " satır işlenir."));
                break;
            }
            try {
                String[] f = line.split(";", -1);
                if (f.length < 3) {
                    throw new IllegalArgumentException("Biçim: TÜR;Başlık;başlangıç;bitiş;bölüm");
                }
                boolean allDay = f[2].strip().length() <= 10 && (f.length < 4 || f[3].strip().length() <= 10);
                Instant s = parseImportDate(f[2], false);
                Instant e = f.length > 3 && !f[3].isBlank() ? parseImportDate(f[3], allDay) : null;
                String endIso = e == null ? null : AcademicTime.fmt(e);
                create(adminId, new AcademicEventRequest(f[0], f[1], AcademicTime.fmt(s), endIso, allDay,
                        f.length > 4 ? f[4] : null, null, publish));
                created++;
            } catch (ApiException ex) {
                errors.add(new ImportError(i + 1, ex.code()));
            } catch (RuntimeException ex) {
                errors.add(new ImportError(i + 1, ex.getMessage() == null ? "Geçersiz satır" : ex.getMessage()));
            }
        }
        return new EventImportResult(created, errors);
    }

    /** YYYY-MM-DD (tum gun; bitis icin gun sonu 23:59) ya da YYYY-MM-DDTHH:mm. */
    private static Instant parseImportDate(String raw, boolean endOfDay) {
        String s = raw.strip();
        try {
            if (s.length() <= 10) {
                LocalDate d = LocalDate.parse(s);
                return endOfDay ? d.atTime(23, 59).atZone(AcademicTime.ZONE).toInstant()
                        : AcademicTime.startOfDay(d);
            }
            return LocalDateTime.parse(s).atZone(AcademicTime.ZONE).toInstant();
        } catch (DateTimeParseException ex) {
            throw new IllegalArgumentException("Tarih geçersiz: " + s);
        }
    }
}
