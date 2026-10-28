package edu.bingol.backend.admin.users.extras;

import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.admin.users.extras.UserExtrasDtos.NotificationRow;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.UserRepository;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

/** Yonetici icin kullanicinin bildirim kutusu gecmisi (salt okunur, sayfali; icerik kisisel veri olabilir). */
@Service
public class AdminUserNotificationService {

    public static final int MAX_SIZE = 100;

    private final NamedParameterJdbcTemplate jdbc;
    private final UserRepository users;

    public AdminUserNotificationService(NamedParameterJdbcTemplate jdbc, UserRepository users) {
        this.jdbc = jdbc;
        this.users = users;
    }

    public PageResponse<NotificationRow> list(Long userId, String type, boolean unreadOnly, int page, int size) {
        Targets.existing(users, userId);
        int s = Math.min(Math.max(size, 1), MAX_SIZE);
        int p = Math.max(page, 0);
        List<String> c = new ArrayList<>(List.of("user_id = :uid"));
        MapSqlParameterSource params = new MapSqlParameterSource("uid", userId);
        if (type != null && !type.isBlank()) {
            try {
                params.addValue("type", NotificationType.valueOf(type.trim().toUpperCase(Locale.ROOT)).name());
            } catch (IllegalArgumentException e) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz bildirim türü.");
            }
            c.add("type = :type");
        }
        if (unreadOnly) {
            c.add("read_at IS NULL");
        }
        String where = String.join(" AND ", c);
        Long total = jdbc.queryForObject("SELECT count(*) FROM notification WHERE " + where, params, Long.class);
        params.addValue("lim", s).addValue("off", (long) p * s);
        List<NotificationRow> rows = jdbc.query("SELECT id, type, subtype, title, body, group_count, read_at, created_at "
                + "FROM notification WHERE " + where + " ORDER BY id DESC LIMIT :lim OFFSET :off", params,
                (rs, i) -> row(rs));
        return PageResponse.of(rows, p, s, total == null ? 0 : total);
    }

    private static NotificationRow row(ResultSet rs) throws SQLException {
        OffsetDateTime read = rs.getObject("read_at", OffsetDateTime.class);
        OffsetDateTime created = rs.getObject("created_at", OffsetDateTime.class);
        return new NotificationRow(rs.getLong("id"), rs.getString("type"), rs.getString("subtype"),
                rs.getString("title"), rs.getString("body"), read != null, rs.getInt("group_count"),
                created == null ? null : created.toInstant().toString(),
                read == null ? null : read.toInstant().toString());
    }
}
