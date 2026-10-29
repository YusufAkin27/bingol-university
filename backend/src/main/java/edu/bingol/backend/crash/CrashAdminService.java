package edu.bingol.backend.crash;

import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.crash.CrashDtos.EventRow;
import edu.bingol.backend.crash.CrashDtos.GroupDetail;
import edu.bingol.backend.crash.CrashDtos.GroupRow;
import edu.bingol.backend.crash.CrashDtos.Summary;
import edu.bingol.backend.crash.CrashDtos.VersionCount;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Yonetici cokme listesi/detayi/durum/silme. Dinamik SQL: siralama beyaz liste, degerler parametreli. */
@Service
public class CrashAdminService {

    static final Set<String> STATUSES = Set.of("NEW", "ACK", "RESOLVED");
    static final Set<String> PLATFORMS = Set.of("ANDROID", "IOS", "OTHER");
    private static final Map<String, String> SORTS = Map.of(
            "lastSeen", "g.last_seen_at DESC, g.id DESC",
            "firstSeen", "g.first_seen_at DESC, g.id DESC",
            "count", "g.event_count DESC, g.id DESC");

    private static final String GROUP_COLS = "g.id, g.error_type, g.message_sample, g.top_frame, g.status, "
            + "g.event_count, g.first_seen_at, g.last_seen_at, g.first_version, g.last_version, g.reopen_count, "
            + "g.status_reason, g.status_by, g.status_at, g.fixed_in_version";

    private final NamedParameterJdbcTemplate jdbc;
    private final Clock clock;

    public CrashAdminService(NamedParameterJdbcTemplate jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
    }

    public PageResponse<GroupRow> list(String status, String platform, String version, String q, String sort,
                                       int page, int size) {
        int p = Math.max(0, page);
        int s = Math.max(1, Math.min(size, 100));
        StringBuilder where = new StringBuilder(" WHERE 1=1");
        MapSqlParameterSource ps = new MapSqlParameterSource();
        if (status != null && !status.isBlank()) {
            where.append(" AND g.status = :status");
            ps.addValue("status", requireStatus(status));
        }
        boolean hasPlatform = platform != null && !platform.isBlank();
        boolean hasVersion = version != null && !version.isBlank();
        if (hasPlatform || hasVersion) {
            where.append(" AND EXISTS (SELECT 1 FROM crash_group_version v WHERE v.group_id = g.id");
            if (hasPlatform) {
                String pl = platform.strip().toUpperCase(Locale.ROOT);
                if (!PLATFORMS.contains(pl)) {
                    throw new ApiException(HttpStatus.BAD_REQUEST, "CRASH_FILTER_INVALID",
                            "Süzgeç değeri geçersiz.");
                }
                where.append(" AND v.platform = :platform");
                ps.addValue("platform", pl);
            }
            if (hasVersion) {
                where.append(" AND v.app_version = :version");
                ps.addValue("version", version.strip());
            }
            where.append(")");
        }
        if (q != null && !q.isBlank()) {
            where.append(" AND (g.error_type ILIKE :q ESCAPE '\\' OR g.top_frame ILIKE :q ESCAPE '\\'"
                    + " OR g.message_sample ILIKE :q ESCAPE '\\')");
            ps.addValue("q", "%" + escapeLike(q.strip()) + "%");
        }
        Long total = jdbc.queryForObject("SELECT count(*) FROM crash_group g" + where, ps, Long.class);
        String order = SORTS.getOrDefault(sort == null ? "" : sort, SORTS.get("lastSeen"));
        ps.addValue("lim", s).addValue("off", (long) p * s);
        List<GroupRow> rows = new ArrayList<>(jdbc.query("SELECT " + GROUP_COLS + " FROM crash_group g" + where
                + " ORDER BY " + order + " LIMIT :lim OFFSET :off", ps, (rs, i) -> mapGroup(rs)));
        attachVersions(rows);
        return PageResponse.of(rows, p, s, total == null ? 0 : total);
    }

    public GroupDetail detail(long id) {
        List<GroupRow> rows = new ArrayList<>(jdbc.query("SELECT " + GROUP_COLS + " FROM crash_group g WHERE g.id = :id",
                Map.of("id", id), (rs, i) -> mapGroup(rs)));
        if (rows.isEmpty()) {
            throw notFound();
        }
        attachVersions(rows);
        List<EventRow> events = jdbc.query("SELECT id, app_version, platform, os_version, device_model, screen, "
                + "fatal, message, stack, occurred_at, received_at FROM crash_event WHERE group_id = :id "
                + "ORDER BY id DESC LIMIT 50", Map.of("id", id), (rs, i) -> new EventRow(rs.getLong("id"),
                rs.getString("app_version"), rs.getString("platform"), rs.getString("os_version"),
                rs.getString("device_model"), rs.getString("screen"), rs.getBoolean("fatal"),
                rs.getString("message"), rs.getString("stack"), instant(rs, "occurred_at"), instant(rs, "received_at")));
        return new GroupDetail(rows.get(0), events);
    }

    public Summary summary() {
        Map<String, Long> by = new HashMap<>();
        jdbc.query("SELECT status, count(*) AS n FROM crash_group GROUP BY status", rs -> {
            by.put(rs.getString("status"), rs.getLong("n"));
        });
        Instant since = clock.instant().minus(Duration.ofHours(24));
        Long ev = jdbc.queryForObject("SELECT count(*) FROM crash_event WHERE received_at >= :since",
                Map.of("since", Timestamp.from(since)), Long.class);
        Long reopened = jdbc.queryForObject(
                "SELECT count(*) FROM crash_group WHERE reopen_count > 0 AND status = 'NEW'", Map.of(), Long.class);
        return new Summary(by.getOrDefault("NEW", 0L), by.getOrDefault("ACK", 0L), by.getOrDefault("RESOLVED", 0L),
                ev == null ? 0 : ev, reopened == null ? 0 : reopened);
    }

    /** Durum degisikligi; gerekce ve yonetici kayda alinir (denetim kaydi ayrica AuditInterceptor'dadir). */
    @Transactional
    public GroupDetail setStatus(long id, String status, String reason, String fixedIn, String actor) {
        String st = requireStatus(status);
        Map<String, Object> g;
        try {
            g = jdbc.queryForMap("SELECT last_version FROM crash_group WHERE id = :id FOR UPDATE", Map.of("id", id));
        } catch (org.springframework.dao.EmptyResultDataAccessException e) {
            throw notFound();
        }
        boolean resolved = "RESOLVED".equals(st);
        String fixed = resolved && fixedIn != null && !fixedIn.isBlank() ? fixedIn.strip() : null;
        MapSqlParameterSource ps = new MapSqlParameterSource().addValue("id", id).addValue("st", st)
                .addValue("reason", clip(reason, 300)).addValue("by", clip(actor, 80))
                .addValue("now", Timestamp.from(clock.instant())).addValue("fixed", fixed)
                .addValue("resolvedAt", resolved ? g.get("last_version") : null);
        jdbc.update("UPDATE crash_group SET status = :st, status_reason = :reason, status_by = :by, status_at = :now, "
                + "fixed_in_version = :fixed, resolved_at_version = :resolvedAt WHERE id = :id", ps);
        return detail(id);
    }

    @Transactional
    public void delete(long id) {
        int n = jdbc.update("DELETE FROM crash_group WHERE id = :id", Map.of("id", id));
        if (n == 0) {
            throw notFound();
        }
    }

    private void attachVersions(List<GroupRow> rows) {
        if (rows.isEmpty()) {
            return;
        }
        List<Long> ids = rows.stream().map(GroupRow::id).toList();
        Map<Long, List<VersionCount>> byGroup = new LinkedHashMap<>();
        jdbc.query("SELECT group_id, app_version, platform, cnt FROM crash_group_version WHERE group_id IN (:ids) "
                + "ORDER BY cnt DESC, app_version DESC", Map.of("ids", ids), rs -> {
            byGroup.computeIfAbsent(rs.getLong("group_id"), k -> new ArrayList<>()).add(
                    new VersionCount(rs.getString("app_version"), rs.getString("platform"), rs.getLong("cnt")));
        });
        for (int i = 0; i < rows.size(); i++) {
            rows.set(i, rows.get(i).withVersions(byGroup.getOrDefault(rows.get(i).id(), List.of())));
        }
    }

    private static GroupRow mapGroup(ResultSet rs) throws SQLException {
        return new GroupRow(rs.getLong("id"), rs.getString("error_type"), rs.getString("message_sample"),
                rs.getString("top_frame"), rs.getString("status"), rs.getLong("event_count"),
                instant(rs, "first_seen_at"), instant(rs, "last_seen_at"), rs.getString("first_version"),
                rs.getString("last_version"), rs.getInt("reopen_count"), rs.getString("status_reason"),
                rs.getString("status_by"), instant(rs, "status_at"), rs.getString("fixed_in_version"), List.of());
    }

    private static Instant instant(ResultSet rs, String col) throws SQLException {
        Timestamp t = rs.getTimestamp(col);
        return t == null ? null : t.toInstant();
    }

    static String requireStatus(String status) {
        String s = status == null ? "" : status.strip().toUpperCase(Locale.ROOT);
        if (!STATUSES.contains(s)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CRASH_STATUS_INVALID",
                    "Durum NEW, ACK veya RESOLVED olmalıdır.");
        }
        return s;
    }

    static String escapeLike(String s) {
        return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }

    private static String clip(String s, int max) {
        if (s == null || s.isBlank()) {
            return null;
        }
        String t = s.strip();
        return t.length() > max ? t.substring(0, max) : t;
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CRASH_NOT_FOUND", "Çökme grubu bulunamadı.");
    }
}
