package edu.bingol.backend.admin;

import edu.bingol.backend.admin.AdminDtos.AdminUserDetail;
import edu.bingol.backend.admin.AdminDtos.AdminUserRow;
import edu.bingol.backend.admin.AdminDtos.Consent;
import edu.bingol.backend.admin.AdminDtos.Counts;
import edu.bingol.backend.analytics.ActivityRepository;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.UserStatus;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.RowCallbackHandler;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/** Yonetici kullanici sorgulari (dinamik filtre icin parametreli JDBC; PostgreSQL). */
@Repository
public class AdminUserRepository {

    static final int RECENT_ACTIVITY_DAYS = 30;
    private static final String ROW_COLUMNS = "id, email, display_name, faculty, department, class_year, language, "
            + "role, status, email_verified, created_at, last_seen_at, avatar_url";

    private final NamedParameterJdbcTemplate jdbc;
    private final ActivityRepository activity;

    public AdminUserRepository(NamedParameterJdbcTemplate jdbc, ActivityRepository activity) {
        this.jdbc = jdbc;
        this.activity = activity;
    }

    public long count(UserFilter f) {
        UserFilter.Where w = f.where();
        Long n = jdbc.queryForObject("SELECT count(*) FROM app_user WHERE " + w.sql(), w.params(), Long.class);
        return n == null ? 0 : n;
    }

    public List<AdminUserRow> page(UserFilter f, String orderBy, int page, int size) {
        UserFilter.Where w = f.where();
        w.params().addValue("lim", size).addValue("off", (long) page * size);
        return jdbc.query("SELECT " + ROW_COLUMNS + " FROM app_user WHERE " + w.sql() + " ORDER BY " + orderBy
                + " LIMIT :lim OFFSET :off", w.params(), (rs, i) -> row(rs));
    }

    /** CSV icin akis: en cok `limit` satir, bellekte biriktirmeden. */
    public void stream(UserFilter f, String orderBy, int limit, java.util.function.Consumer<AdminUserRow> sink) {
        UserFilter.Where w = f.where();
        w.params().addValue("lim", limit);
        jdbc.query("SELECT " + ROW_COLUMNS + " FROM app_user WHERE " + w.sql() + " ORDER BY " + orderBy + " LIMIT :lim",
                w.params(), (RowCallbackHandler) rs -> sink.accept(row(rs)));
    }

    public Optional<AdminUserDetail> detail(Long id) {
        MapSqlParameterSource p = new MapSqlParameterSource("id", id);
        List<AdminUserDetail> rows = jdbc.query("SELECT u.*, "
                + "(SELECT count(*) FROM device d WHERE d.user_id = u.id) AS device_count, "
                + "(SELECT count(*) FROM feedback f WHERE f.user_id = u.id) AS c_feedback, "
                + "(SELECT count(*) FROM support_ticket t WHERE t.user_id = u.id) AS c_tickets, "
                + "(SELECT count(*) FROM report r WHERE r.target_type = 'USER' AND r.target_id = u.id) AS c_against, "
                + "(SELECT count(*) FROM report r WHERE r.reporter_id = u.id) AS c_filed, "
                + "(SELECT count(*) FROM conversation_member cm WHERE cm.user_id = u.id AND cm.left_at IS NULL) AS c_conv, "
                + "(SELECT count(*) FROM community_member m WHERE m.user_id = u.id AND m.status = 'ACTIVE') AS c_comm, "
                + "(SELECT count(*) FROM user_event e WHERE e.created_by = u.id) AS c_events, "
                + "(SELECT count(*) FROM bookmark b WHERE b.user_id = u.id) AS c_bookmarks "
                + "FROM app_user u WHERE u.id = :id", p, (rs, i) -> detailRow(rs));
        if (rows.isEmpty()) {
            return Optional.empty();
        }
        AdminUserDetail d = rows.get(0);
        List<String> platforms = jdbc.queryForList(
                "SELECT DISTINCT platform FROM device WHERE user_id = :id ORDER BY platform", p, String.class);
        List<Consent> consents = jdbc.query("SELECT doc_type, version, accepted_at FROM legal_acceptance "
                + "WHERE user_id = :id ORDER BY accepted_at DESC, id DESC", p,
                (rs, i) -> new Consent(rs.getString("doc_type"), rs.getInt("version"), ts(rs, "accepted_at")));
        return Optional.of(new AdminUserDetail(d.id(), d.email(), d.displayName(), d.faculty(), d.department(),
                d.classYear(), d.language(), d.role(), d.status(), d.emailVerified(), d.createdAt(), d.lastSeenAt(),
                d.avatarUrl(), d.bio(), d.suspendedReason(), d.deletedAt(), d.deviceCount(), platforms, d.counts(),
                consents, activity.recentDays(id, RECENT_ACTIVITY_DAYS)));
    }

    private static AdminUserRow row(ResultSet rs) throws SQLException {
        return new AdminUserRow(rs.getLong("id"), rs.getString("email"), rs.getString("display_name"),
                rs.getString("faculty"), rs.getString("department"), shortOrNull(rs, "class_year"),
                rs.getString("language"), Role.valueOf(rs.getString("role")), UserStatus.valueOf(rs.getString("status")),
                rs.getBoolean("email_verified"), ts(rs, "created_at"), ts(rs, "last_seen_at"), rs.getString("avatar_url"));
    }

    /** Alt listeler (platforms, consents, recentActivity) sonradan doldurulur. */
    private static AdminUserDetail detailRow(ResultSet rs) throws SQLException {
        return new AdminUserDetail(rs.getLong("id"), rs.getString("email"), rs.getString("display_name"),
                rs.getString("faculty"), rs.getString("department"), shortOrNull(rs, "class_year"),
                rs.getString("language"), Role.valueOf(rs.getString("role")), UserStatus.valueOf(rs.getString("status")),
                rs.getBoolean("email_verified"), ts(rs, "created_at"), ts(rs, "last_seen_at"), rs.getString("avatar_url"),
                rs.getString("bio"), rs.getString("suspended_reason"), ts(rs, "deleted_at"), rs.getLong("device_count"),
                List.of(), new Counts(rs.getLong("c_feedback"), rs.getLong("c_tickets"), rs.getLong("c_against"),
                        rs.getLong("c_filed"), rs.getLong("c_conv"), rs.getLong("c_comm"), rs.getLong("c_events"),
                        rs.getLong("c_bookmarks")),
                List.of(), List.of());
    }

    static String ts(ResultSet rs, String col) throws SQLException {
        OffsetDateTime t = rs.getObject(col, OffsetDateTime.class);
        return t == null ? null : t.toInstant().toString();
    }

    private static Short shortOrNull(ResultSet rs, String col) throws SQLException {
        short v = rs.getShort(col);
        return rs.wasNull() ? null : v;
    }

    /** Test/yardimci: sabit kolon sirasi (CSV basligi ile birebir). */
    static final List<String> CSV_HEADER = List.of("id", "email", "displayName", "faculty", "department", "classYear",
            "language", "role", "status", "emailVerified", "createdAt", "lastSeenAt");

    static List<Object> csvCells(AdminUserRow r) {
        return java.util.Arrays.asList(r.id(), r.email(), r.displayName(), r.faculty(), r.department(), r.classYear(),
                r.language(), r.role(), r.status(), r.emailVerified(), r.createdAt(), r.lastSeenAt());
    }

}
