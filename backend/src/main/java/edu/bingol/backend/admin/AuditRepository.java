package edu.bingol.backend.admin;

import edu.bingol.backend.admin.AdminDtos.AuditRow;
import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/** admin_audit tablosu: yalnizca ekleme ve filtreli okuma (guncelleme/silme yok). */
@Repository
public class AuditRepository {

    private static final String COLS = "id, admin_id, admin_email, method, path, status, created_at, ip, "
            + "target_type, target_id, reason, summary, request_id";

    private final NamedParameterJdbcTemplate jdbc;

    public AuditRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** v2 ek alanlari (hepsi NULL'a izinli). */
    public record Details(String targetType, String targetId, String reason, String summary, String requestId) {
        static final Details NONE = new Details(null, null, null, null, null);
    }

    /** v1 uyumu: ek alansiz kayit. */
    public void insert(Long adminId, String fallbackEmail, String method, String path, int status, String ip) {
        insert(adminId, fallbackEmail, method, path, status, ip, Details.NONE);
    }

    /**
     * Kayit ekler. E-posta, adminId biliniyorsa app_user'dan alinir; Basic auth yoneticisi icin `fallbackEmail`
     * (kullanici adi) yazilir. Govde/sorgu dizgesi KAYDEDILMEZ; yalniz sebep ve kisa ozet saklanir.
     */
    public void insert(Long adminId, String fallbackEmail, String method, String path, int status, String ip,
                       Details d) {
        jdbc.update("INSERT INTO admin_audit (admin_id, admin_email, method, path, status, ip, target_type, target_id, "
                + "reason, summary, request_id) VALUES (:adminId, "
                + "COALESCE((SELECT email FROM app_user WHERE id = :adminId), :fallback), :method, :path, :status, :ip, "
                + ":tt, :tid, :reason, :summary, :rid)",
                new MapSqlParameterSource().addValue("adminId", adminId).addValue("fallback", fallbackEmail)
                        .addValue("method", truncate(method, 8)).addValue("path", truncate(path, 300))
                        .addValue("status", status).addValue("ip", truncate(ip, 64))
                        .addValue("tt", truncate(d.targetType(), 32)).addValue("tid", truncate(d.targetId(), 64))
                        .addValue("reason", truncate(d.reason(), AuditContext.MAX_REASON))
                        .addValue("summary", truncate(d.summary(), AuditContext.MAX_SUMMARY))
                        .addValue("rid", truncate(d.requestId(), 64)));
    }

    /** Liste suzgeci; bos alanlar uygulanmaz. `from` dahil, `to` haric (ust sinir). */
    public record Filter(Long adminId, String method, String q, Instant from, Instant to, String targetType,
                         String targetId, String status) {
        public Filter(Long adminId, String method, String q) {
            this(adminId, method, q, null, null, null, null, null);
        }
    }

    private static String where(Filter f, MapSqlParameterSource p) {
        List<String> c = new ArrayList<>();
        if (f.adminId() != null) {
            c.add("admin_id = :adminId");
            p.addValue("adminId", f.adminId());
        }
        if (f.method() != null && !f.method().isBlank()) {
            c.add("method = :method");
            p.addValue("method", f.method().trim().toUpperCase(java.util.Locale.ROOT));
        }
        if (f.from() != null) {
            c.add("created_at >= :from");
            p.addValue("from", java.sql.Timestamp.from(f.from()));
        }
        if (f.to() != null) {
            c.add("created_at < :to");
            p.addValue("to", java.sql.Timestamp.from(f.to()));
        }
        if (f.targetType() != null && !f.targetType().isBlank()) {
            c.add("target_type = :tt");
            p.addValue("tt", f.targetType().trim().toUpperCase(java.util.Locale.ROOT));
        }
        if (f.targetId() != null && !f.targetId().isBlank()) {
            c.add("target_id = :tid");
            p.addValue("tid", f.targetId().trim());
        }
        statusClause(f.status(), c, p);
        if (f.q() != null && !f.q().isBlank()) {
            // T-019: users.pii olmayan profil yonetici e-postasi uzerinden arayarak adresi yeniden kuramaz
            c.add("(path ILIKE :q ESCAPE '\\' "
                    + (PermissionAwareMasking.canSeePii() ? "OR admin_email ILIKE :q ESCAPE '\\' " : "")
                    + "OR reason ILIKE :q ESCAPE '\\' "
                    + "OR summary ILIKE :q ESCAPE '\\' OR target_id ILIKE :q ESCAPE '\\')");
            p.addValue("q", "%" + UserFilter.escapeLike(f.q().trim()) + "%");
        }
        return c.isEmpty() ? "TRUE" : String.join(" AND ", c);
    }

    /** `status`: tam kod (403) ya da sinif (2xx, 3xx, 4xx, 5xx); gecersiz deger yok sayilmaz, bos sonuc verir. */
    private static void statusClause(String s, List<String> c, MapSqlParameterSource p) {
        if (s == null || s.isBlank()) {
            return;
        }
        String v = s.trim().toLowerCase(java.util.Locale.ROOT);
        if (v.matches("[1-5]xx")) {
            int base = (v.charAt(0) - '0') * 100;
            c.add("status >= :sLo AND status < :sHi");
            p.addValue("sLo", base).addValue("sHi", base + 100);
        } else if (v.matches("\\d{3}")) {
            c.add("status = :sEq");
            p.addValue("sEq", Integer.parseInt(v));
        } else {
            c.add("1 = 0");
        }
    }

    public long count(Filter f) {
        MapSqlParameterSource p = new MapSqlParameterSource();
        Long n = jdbc.queryForObject("SELECT count(*) FROM admin_audit WHERE " + where(f, p), p, Long.class);
        return n == null ? 0 : n;
    }

    /** En yeni once. */
    public List<AuditRow> page(Filter f, int page, int size) {
        MapSqlParameterSource p = new MapSqlParameterSource();
        String w = where(f, p);
        p.addValue("lim", size).addValue("off", (long) page * size);
        return jdbc.query("SELECT " + COLS + " FROM admin_audit WHERE " + w
                + " ORDER BY id DESC LIMIT :lim OFFSET :off", p, (rs, i) -> row(rs));
    }

    /** CSV icin akis: en yeni once, en cok `limit` satir; satirlar bellekte biriktirilmez. */
    public void stream(Filter f, int limit, Consumer<AuditRow> sink) {
        MapSqlParameterSource p = new MapSqlParameterSource();
        String w = where(f, p);
        p.addValue("lim", limit);
        jdbc.query("SELECT " + COLS + " FROM admin_audit WHERE " + w + " ORDER BY id DESC LIMIT :lim", p,
                (org.springframework.jdbc.core.RowCallbackHandler) rs -> sink.accept(row(rs)));
    }

    private static AuditRow row(ResultSet rs) throws SQLException {
        long adminId = rs.getLong("admin_id");
        Long admin = rs.wasNull() ? null : adminId;
        // T-018: users.pii olmayan profil (VIEWER) yonetici e-postasini ve IP'sini maskeli gorur (JSON ve CSV ortak)
        return new AuditRow(rs.getLong("id"), admin, PermissionAwareMasking.email(rs.getString("admin_email")),
                rs.getString("method"), rs.getString("path"), rs.getInt("status"),
                AdminUserRepository.ts(rs, "created_at"), PermissionAwareMasking.opaque(rs.getString("ip")),
                rs.getString("target_type"), rs.getString("target_id"), rs.getString("reason"),
                rs.getString("summary"), rs.getString("request_id"));
    }

    private static String truncate(String s, int max) {
        return s == null || s.length() <= max ? s : s.substring(0, max);
    }
}
