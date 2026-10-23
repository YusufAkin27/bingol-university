package edu.bingol.backend.admin;

import edu.bingol.backend.admin.AdminDtos.AuditRow;
import java.util.ArrayList;
import java.util.List;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/** admin_audit tablosu: yalnizca ekleme ve filtreli okuma (guncelleme/silme yok). */
@Repository
public class AuditRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public AuditRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Kayit ekler. E-posta, adminId biliniyorsa app_user'dan alinir; Basic auth yoneticisi icin `fallbackEmail`
     * (kullanici adi) yazilir. Govde/sorgu dizgesi KAYDEDILMEZ.
     */
    public void insert(Long adminId, String fallbackEmail, String method, String path, int status, String ip) {
        jdbc.update("INSERT INTO admin_audit (admin_id, admin_email, method, path, status, ip) VALUES "
                + "(:adminId, COALESCE((SELECT email FROM app_user WHERE id = :adminId), :fallback), :method, :path, :status, :ip)",
                new MapSqlParameterSource().addValue("adminId", adminId).addValue("fallback", fallbackEmail)
                        .addValue("method", truncate(method, 8)).addValue("path", truncate(path, 300))
                        .addValue("status", status).addValue("ip", truncate(ip, 64)));
    }

    public record Filter(Long adminId, String method, String q) {}

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
        if (f.q() != null && !f.q().isBlank()) {
            c.add("(path ILIKE :q ESCAPE '\\' OR admin_email ILIKE :q ESCAPE '\\')");
            p.addValue("q", "%" + UserFilter.escapeLike(f.q().trim()) + "%");
        }
        return c.isEmpty() ? "TRUE" : String.join(" AND ", c);
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
        return jdbc.query("SELECT id, admin_id, admin_email, method, path, status, created_at, ip FROM admin_audit "
                + "WHERE " + w + " ORDER BY id DESC LIMIT :lim OFFSET :off", p, (rs, i) -> {
                    long adminId = rs.getLong("admin_id");
                    Long admin = rs.wasNull() ? null : adminId;
                    return new AuditRow(rs.getLong("id"), admin, rs.getString("admin_email"),
                            rs.getString("method"), rs.getString("path"), rs.getInt("status"),
                            AdminUserRepository.ts(rs, "created_at"), rs.getString("ip"));
                });
    }

    private static String truncate(String s, int max) {
        return s == null || s.length() <= max ? s : s.substring(0, max);
    }
}
