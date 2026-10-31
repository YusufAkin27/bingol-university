package edu.bingol.backend.academic;

import static edu.bingol.backend.academic.AcademicSupport.adminText;
import static edu.bingol.backend.academic.AcademicSupport.insert;
import static edu.bingol.backend.academic.AcademicSupport.notFound;

import edu.bingol.backend.academic.AcademicDtos.AdminAnnouncementView;
import edu.bingol.backend.academic.AcademicDtos.AnnouncementPage;
import edu.bingol.backend.academic.AcademicDtos.AnnouncementRequest;
import edu.bingol.backend.academic.AcademicDtos.AnnouncementView;
import edu.bingol.backend.academic.AcademicDtos.Page;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.profanity.ContentGuard;
import edu.bingol.backend.moderation.profanity.ContentGuard.Entity;
import java.net.URI;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Bolum/fakulte/sinif kapsamli duyurular: kullanici akisi (imecli), okundu bilgisi ve yonetici CRUD. */
@Service
public class DepartmentAnnouncementService {

    static final int LIST_BODY_MAX = 200;
    private static final String VISIBLE = "a.published = TRUE AND a.publish_at <= ? AND (a.expires_at IS NULL OR a.expires_at > ?)";
    private static final String PIN = "(CASE WHEN a.pinned = TRUE THEN 1 ELSE 0 END)";

    private final JdbcTemplate jdbc;
    private final AcademicAudience audience;
    private final AnnouncementNotifier notifier;
    private final Clock clock;
    private ContentGuard guard;

    @Autowired
    public DepartmentAnnouncementService(JdbcTemplate jdbc, AcademicAudience audience, AnnouncementNotifier notifier) {
        this(jdbc, audience, notifier, Clock.systemUTC());
    }

    DepartmentAnnouncementService(JdbcTemplate jdbc, AcademicAudience audience, AnnouncementNotifier notifier, Clock clock) {
        this.jdbc = jdbc;
        this.audience = audience;
        this.notifier = notifier;
        this.clock = clock;
    }

    @Autowired(required = false)
    void setGuard(ContentGuard guard) {
        this.guard = guard;
    }

    // ---- kapsam SQL'i ----

    /** Kullanicinin kapsamina uyan duyurular icin kosul (alias a). Bos kullanici alani yalniz kapsamsiz duyuruyu eslestirir. */
    static void audienceSql(StringBuilder sql, List<Object> args, AcademicAudience.Who me) {
        field(sql, args, "a.department", me.department(), false);
        field(sql, args, "a.faculty", me.faculty(), false);
        field(sql, args, "a.grade", me.grade(), true);
    }

    /**
     * Kapsam kosulu (T-042): bolum/fakulte {@link AudienceKey} anahtariyla (Java ve SQL ayni kural; "Isletme/Iktisat/
     * Ilahiyat" gibi buyuk I-nokta ile baslayan adlar da eslesir), sinif BUYUK harf. Bos kullanici alani yalniz
     * kapsamsiz duyuruyu eslestirir.
     */
    private static void field(StringBuilder sql, List<Object> args, String col, String value, boolean grade) {
        String key = grade ? (value == null || value.isBlank() ? null : value.strip().toUpperCase(java.util.Locale.ROOT))
                : AudienceKey.of(value);
        if (key == null) {
            sql.append(" AND ").append(col).append(" IS NULL");
        } else {
            sql.append(" AND (").append(col).append(" IS NULL OR ")
                    .append(grade ? "UPPER(TRIM(" + col + "))" : AudienceKey.sql(col)).append(" = ?)");
            args.add(key);
        }
    }

    /** Bu duyuru kullanicinin kapsamina giriyor mu (SQL eki); get/markRead/akis tek kural (T-046, K-19). */
    private static void scopeOf(StringBuilder sql, List<Object> args, AcademicAudience.Who me) {
        audienceSql(sql, args, me);
    }

    /** Kapsamsiz duyuru (bolum, fakulte ve sinif bos): "Tumu" sekmesi yalniz bunlari listeler (K-19). */
    private static final String UNSCOPED = " AND a.department IS NULL AND a.faculty IS NULL AND a.grade IS NULL";

    /** Hedef kitle (aktif kullanicilar): duyurunun bolum/fakulte/sinif alani bossa kisitsiz. */
    static List<Long> audienceIds(JdbcTemplate jdbc, String dept, String faculty, String grade) {
        StringBuilder sql = new StringBuilder("SELECT id FROM app_user WHERE status = 'ACTIVE' AND deleted_at IS NULL");
        List<Object> args = new ArrayList<>();
        userField(sql, args, "department", dept, false);
        userField(sql, args, "faculty", faculty, false);
        userField(sql, args, "grade", grade, true);
        return jdbc.queryForList(sql.toString(), Long.class, args.toArray());
    }

    private static void userField(StringBuilder sql, List<Object> args, String col, String scope, boolean grade) {
        if (scope == null || scope.isBlank()) {
            return;
        }
        if (grade) {
            sql.append(" AND UPPER(TRIM(").append(col).append(")) = ?");
            args.add(scope.strip().toUpperCase(java.util.Locale.ROOT));
        } else {
            sql.append(" AND ").append(AudienceKey.sql(col)).append(" = ?");
            args.add(AudienceKey.of(scope));
        }
    }

    public long audienceCount(String dept, String faculty, String grade) {
        return audienceIds(jdbc, dept, faculty, ExamService.grade(grade)).size();
    }

    // ---- kullanici ----

    private static AnnouncementView view(java.sql.ResultSet rs, boolean full) throws java.sql.SQLException {
        String body = rs.getString("body");
        boolean cut = !full && body.length() > LIST_BODY_MAX;
        return new AnnouncementView(rs.getLong("id"), rs.getString("title"), cut ? body.substring(0, LIST_BODY_MAX) : body, cut,
                rs.getString("department"), rs.getString("faculty"), rs.getString("grade"), rs.getBoolean("pinned"),
                AcademicTime.fmt(rs.getTimestamp("publish_at")), AcademicTime.fmt(rs.getTimestamp("expires_at")),
                rs.getString("attachment_url"), rs.getBoolean("is_read"), AcademicTime.fmt(rs.getTimestamp("created_at")));
    }

    private static final String USER_SELECT = "SELECT a.id, a.title, a.body, a.department, a.faculty, a.grade, a.pinned, a.publish_at, "
            + "a.expires_at, a.attachment_url, a.created_at, (r.user_id IS NOT NULL) AS is_read FROM department_announcement a "
            + "LEFT JOIN announcement_read r ON r.announcement_id = a.id AND r.user_id = ? ";

    public AnnouncementPage feed(Long uid, String scope, String cursor, int size) {
        int n = Math.min(Math.max(size, 1), 50);
        boolean mine = scope == null || !scope.equalsIgnoreCase("all");
        Timestamp now = Timestamp.from(clock.instant());
        StringBuilder sql = new StringBuilder(USER_SELECT).append("WHERE ").append(VISIBLE);
        List<Object> args = new ArrayList<>(List.of(uid, now, now));
        if (mine) {
            scopeOf(sql, args, audience.of(uid));
        } else {
            sql.append(UNSCOPED); // K-19 (b): kapsam disi duyuru "Tumu"de de listelenmez/sizmaz
        }
        if (cursor != null && !cursor.isBlank()) {
            Cursor c = Cursor.parse(cursor);
            Timestamp ts = Timestamp.from(c.at());
            sql.append(" AND (").append(PIN).append(" < ? OR (").append(PIN).append(" = ? AND (a.publish_at < ? OR (a.publish_at = ? AND a.id < ?))))");
            args.addAll(List.of(c.pin(), c.pin(), ts, ts, c.id()));
        }
        sql.append(" ORDER BY ").append(PIN).append(" DESC, a.publish_at DESC, a.id DESC LIMIT ?");
        args.add(n + 1);
        record Row(AnnouncementView v, boolean pinned, Instant at) {}
        List<Row> rows = jdbc.query(sql.toString(), (rs, i) -> new Row(view(rs, false), rs.getBoolean("pinned"),
                rs.getTimestamp("publish_at").toInstant()), args.toArray());
        boolean more = rows.size() > n;
        List<Row> page = more ? rows.subList(0, n) : rows;
        String next = null;
        if (more) {
            Row last = page.get(page.size() - 1);
            next = new Cursor(last.pinned() ? 1 : 0, last.at(), last.v().id()).encode();
        }
        return new AnnouncementPage(page.stream().map(Row::v).toList(), next);
    }

    /** Opak imec: pin.epochSecond.nano.id */
    record Cursor(int pin, Instant at, long id) {
        String encode() {
            return pin + "." + at.getEpochSecond() + "." + at.getNano() + "." + id;
        }

        static Cursor parse(String s) {
            try {
                String[] p = s.strip().split("\\.");
                if (p.length != 4) {
                    throw new NumberFormatException();
                }
                int pin = Integer.parseInt(p[0]);
                if (pin != 0 && pin != 1) {
                    throw new NumberFormatException();
                }
                return new Cursor(pin, Instant.ofEpochSecond(Long.parseLong(p[1]), Long.parseLong(p[2])), Long.parseLong(p[3]));
            } catch (RuntimeException e) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ANNOUNCEMENT_CURSOR_INVALID", "Geçersiz sayfa imleci.");
            }
        }
    }

    @Transactional
    public AnnouncementView get(Long uid, Long id) {
        Timestamp now = Timestamp.from(clock.instant());
        // T-046: ID ile erisimde de kapsam kurali gecerli (kapsam disi / gizli duyuru 404)
        StringBuilder sql = new StringBuilder(USER_SELECT).append("WHERE a.id = ? AND ").append(VISIBLE);
        List<Object> args = new ArrayList<>(List.of(uid, id, now, now));
        scopeOf(sql, args, audience.of(uid));
        List<AnnouncementView> r = jdbc.query(sql.toString(), (rs, i) -> view(rs, true), args.toArray());
        if (r.isEmpty()) {
            throw notFound("ANNOUNCEMENT_NOT_FOUND", "Duyuru bulunamadı.");
        }
        markRead(uid, id);
        AnnouncementView v = r.get(0);
        return new AnnouncementView(v.id(), v.title(), v.body(), false, v.department(), v.faculty(), v.grade(), v.pinned(),
                v.publishAt(), v.expiresAt(), v.attachmentUrl(), true, v.createdAt());
    }

    @Transactional
    public void markRead(Long uid, Long id) {
        Timestamp now = Timestamp.from(clock.instant());
        StringBuilder vis = new StringBuilder("SELECT COUNT(*) FROM department_announcement a WHERE a.id = ? AND ").append(VISIBLE);
        List<Object> vargs = new ArrayList<>(List.of(id, now, now));
        scopeOf(vis, vargs, audience.of(uid));
        Long visible = jdbc.queryForObject(vis.toString(), Long.class, vargs.toArray());
        if (visible == null || visible == 0) {
            throw notFound("ANNOUNCEMENT_NOT_FOUND", "Duyuru bulunamadı.");
        }
        try {
            jdbc.update("INSERT INTO announcement_read (announcement_id, user_id, read_at) SELECT ?, ?, ? WHERE NOT EXISTS "
                    + "(SELECT 1 FROM announcement_read WHERE announcement_id = ? AND user_id = ?)", id, uid, now, id, uid);
        } catch (DuplicateKeyException ignore) {
            // es zamanli istek zaten isaretledi
        }
    }

    @Transactional
    public void markAllRead(Long uid) {
        Timestamp now = Timestamp.from(clock.instant());
        StringBuilder sql = new StringBuilder("INSERT INTO announcement_read (announcement_id, user_id, read_at) SELECT a.id, ?, ? "
                + "FROM department_announcement a WHERE ").append(VISIBLE);
        List<Object> args = new ArrayList<>(List.of(uid, now, now, now));
        audienceSql(sql, args, audience.of(uid));
        sql.append(" AND NOT EXISTS (SELECT 1 FROM announcement_read r WHERE r.announcement_id = a.id AND r.user_id = ?)");
        args.add(uid);
        try {
            jdbc.update(sql.toString(), args.toArray());
        } catch (DuplicateKeyException ignore) {
            // yaris: baska istek ekledi
        }
    }

    public long unreadCount(Long uid) {
        Timestamp now = Timestamp.from(clock.instant());
        StringBuilder sql = new StringBuilder("SELECT COUNT(*) FROM department_announcement a WHERE ").append(VISIBLE);
        List<Object> args = new ArrayList<>(List.of(now, now));
        audienceSql(sql, args, audience.of(uid));
        sql.append(" AND NOT EXISTS (SELECT 1 FROM announcement_read r WHERE r.announcement_id = a.id AND r.user_id = ?)");
        args.add(uid);
        Long n = jdbc.queryForObject(sql.toString(), Long.class, args.toArray());
        return n == null ? 0 : n;
    }

    // ---- yonetici ----

    private static final RowMapper<AdminAnnouncementView> ADMIN_ROW = (rs, i) -> new AdminAnnouncementView(rs.getLong("id"),
            rs.getString("title"), rs.getString("body"), rs.getString("department"), rs.getString("faculty"), rs.getString("grade"),
            rs.getBoolean("pinned"), AcademicTime.fmt(rs.getTimestamp("publish_at")), AcademicTime.fmt(rs.getTimestamp("expires_at")),
            rs.getString("attachment_url"), rs.getBoolean("published"), rs.getBoolean("notify"),
            AcademicTime.fmt(rs.getTimestamp("notified_at")), rs.getObject("created_by") == null ? null : rs.getLong("created_by"),
            rs.getLong("read_count"), AcademicTime.fmt(rs.getTimestamp("created_at")));

    private static final String ADMIN_SELECT = "SELECT a.id, a.title, a.body, a.department, a.faculty, a.grade, a.pinned, a.publish_at, "
            + "a.expires_at, a.attachment_url, a.published, a.notify, a.notified_at, a.created_by, a.created_at, "
            + "(SELECT COUNT(*) FROM announcement_read r WHERE r.announcement_id = a.id) AS read_count FROM department_announcement a ";

    public Page<AdminAnnouncementView> adminList(int page, int size, String status, String q) {
        int p = Math.max(page, 0);
        int s = Math.min(Math.max(size, 1), 100);
        Timestamp now = Timestamp.from(clock.instant());
        StringBuilder where = new StringBuilder("WHERE 1 = 1");
        List<Object> args = new ArrayList<>();
        switch (status == null ? "all" : status.toLowerCase(java.util.Locale.ROOT)) {
            case "draft" -> where.append(" AND a.published = FALSE");
            case "scheduled" -> {
                where.append(" AND a.published = TRUE AND a.publish_at > ?");
                args.add(now);
            }
            case "active" -> {
                where.append(" AND ").append(VISIBLE);
                args.add(now);
                args.add(now);
            }
            case "expired" -> {
                where.append(" AND a.published = TRUE AND a.expires_at IS NOT NULL AND a.expires_at <= ?");
                args.add(now);
            }
            default -> { }
        }
        if (q != null && !q.isBlank()) {
            where.append(" AND LOWER(a.title) LIKE ? ESCAPE '\\'");
            args.add("%" + q.strip().toLowerCase(java.util.Locale.ROOT).replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%");
        }
        Long total = jdbc.queryForObject("SELECT COUNT(*) FROM department_announcement a " + where, Long.class, args.toArray());
        List<Object> a2 = new ArrayList<>(args);
        a2.add(s);
        a2.add((long) p * s);
        List<AdminAnnouncementView> items = jdbc.query(ADMIN_SELECT + where + " ORDER BY a.publish_at DESC, a.id DESC LIMIT ? OFFSET ?",
                ADMIN_ROW, a2.toArray());
        return new Page<>(items, p, s, total == null ? 0 : total);
    }

    public AdminAnnouncementView adminGet(Long id) {
        List<AdminAnnouncementView> r = jdbc.query(ADMIN_SELECT + "WHERE a.id = ?", ADMIN_ROW, id);
        if (r.isEmpty()) {
            throw notFound("ANNOUNCEMENT_NOT_FOUND", "Duyuru bulunamadı.");
        }
        return r.get(0);
    }

    static String url(String raw) {
        String u = adminText(raw, 500, "attachmentUrl", false, "ANNOUNCEMENT_URL_INVALID");
        if (u == null) {
            return null;
        }
        try {
            URI uri = URI.create(u);
            if (!"https".equalsIgnoreCase(uri.getScheme()) || uri.getHost() == null) {
                throw new IllegalArgumentException();
            }
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ANNOUNCEMENT_URL_INVALID", "Bağlantı yalnızca https:// olabilir.");
        }
        return u;
    }

    @Transactional
    public AdminAnnouncementView create(Long adminId, AnnouncementRequest r) {
        String title = adminText(r.title(), 150, "title", true, "ANNOUNCEMENT_INVALID");
        String body = adminText(r.body(), 4000, "body", true, "ANNOUNCEMENT_INVALID");
        String dept = adminText(r.department(), 120, "department", false, "ANNOUNCEMENT_INVALID");
        String faculty = adminText(r.faculty(), 120, "faculty", false, "ANNOUNCEMENT_INVALID");
        String grade = ExamService.grade(r.grade());
        Instant publishAt = r.publishAt() == null || r.publishAt().isBlank() ? clock.instant() : AcademicTime.parseInstant(r.publishAt());
        Instant expires = r.expiresAt() == null || r.expiresAt().isBlank() ? null : AcademicTime.parseInstant(r.expiresAt());
        if (expires != null && !expires.isAfter(publishAt)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ANNOUNCEMENT_INVALID", "{0} geçersiz.", "expiresAt");
        }
        String attachment = url(r.attachmentUrl());
        ContentGuard.clean(guard, Entity.ANNOUNCEMENT, "title", adminId, title);
        ContentGuard.clean(guard, Entity.ANNOUNCEMENT, "body", adminId, body);
        long id = insert(jdbc, "INSERT INTO department_announcement (title, body, department, faculty, grade, pinned, created_by, "
                + "publish_at, expires_at, attachment_url, published, notify) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                title, body, dept, faculty, grade, Boolean.TRUE.equals(r.pinned()), adminId, Timestamp.from(publishAt),
                expires == null ? null : Timestamp.from(expires), attachment, r.published() == null || r.published(),
                Boolean.TRUE.equals(r.notifyUsers()));
        notifier.dispatchIfDue(id);
        return adminGet(id);
    }

    @Transactional
    public AdminAnnouncementView update(Long adminId, Long id, AnnouncementRequest r) {
        AdminAnnouncementView cur = adminGet(id);
        String title = r.title() != null ? adminText(r.title(), 150, "title", true, "ANNOUNCEMENT_INVALID") : cur.title();
        String body = r.body() != null ? adminText(r.body(), 4000, "body", true, "ANNOUNCEMENT_INVALID") : cur.body();
        String dept = r.department() != null ? adminText(r.department(), 120, "department", false, "ANNOUNCEMENT_INVALID") : cur.department();
        String faculty = r.faculty() != null ? adminText(r.faculty(), 120, "faculty", false, "ANNOUNCEMENT_INVALID") : cur.faculty();
        String grade = r.grade() != null ? ExamService.grade(r.grade()) : cur.grade();
        Instant publishAt = r.publishAt() != null && !r.publishAt().isBlank() ? AcademicTime.parseInstant(r.publishAt())
                : AcademicTime.parseInstant(cur.publishAt());
        Instant expires = r.expiresAt() != null ? (r.expiresAt().isBlank() ? null : AcademicTime.parseInstant(r.expiresAt()))
                : (cur.expiresAt() == null ? null : AcademicTime.parseInstant(cur.expiresAt()));
        if (expires != null && !expires.isAfter(publishAt)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ANNOUNCEMENT_INVALID", "{0} geçersiz.", "expiresAt");
        }
        String attachment = r.attachmentUrl() != null ? url(r.attachmentUrl()) : cur.attachmentUrl();
        ContentGuard.changed(guard, Entity.ANNOUNCEMENT, "title", adminId, cur.title(), title);
        ContentGuard.changed(guard, Entity.ANNOUNCEMENT, "body", adminId, cur.body(), body);
        jdbc.update("UPDATE department_announcement SET title = ?, body = ?, department = ?, faculty = ?, grade = ?, pinned = ?, "
                + "publish_at = ?, expires_at = ?, attachment_url = ?, published = ?, notify = ? WHERE id = ?",
                title, body, dept, faculty, grade, r.pinned() != null ? r.pinned() : cur.pinned(), Timestamp.from(publishAt),
                expires == null ? null : Timestamp.from(expires), attachment, r.published() != null ? r.published() : cur.published(),
                r.notifyUsers() != null ? r.notifyUsers() : cur.notifyUsers(), id);
        notifier.dispatchIfDue(id);
        return adminGet(id);
    }

    @Transactional
    public void delete(Long id) {
        if (jdbc.update("DELETE FROM department_announcement WHERE id = ?", id) == 0) {
            throw notFound("ANNOUNCEMENT_NOT_FOUND", "Duyuru bulunamadı.");
        }
    }

    @Transactional
    public AdminAnnouncementView setPublished(Long id, boolean published) {
        adminGet(id);
        jdbc.update("UPDATE department_announcement SET published = ? WHERE id = ?", published, id);
        if (published) {
            notifier.dispatchIfDue(id);
        }
        return adminGet(id);
    }
}
