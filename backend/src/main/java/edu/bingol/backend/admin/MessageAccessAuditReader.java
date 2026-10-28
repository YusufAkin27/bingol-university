package edu.bingol.backend.admin;

import edu.bingol.backend.admin.AdminDtos.MessageAccessRow;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/** message_access_audit okuma (yalnızca-ekleme tablosu; yazma crypto.MessageAccessAuditRepository'de). İçerik tutmaz. */
@Repository
public class MessageAccessAuditReader {

    /** Süzgeç: boş alanlar uygulanmaz. `from` dahil, `to` hariç. */
    public record Filter(Long adminId, Long targetUserId, Long conversationId, String kind, String q, Instant from,
                         Instant to) {}

    private final NamedParameterJdbcTemplate jdbc;

    public MessageAccessAuditReader(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static String where(Filter f, MapSqlParameterSource p) {
        List<String> c = new ArrayList<>();
        if (f.adminId() != null) {
            c.add("a.admin_id = :adminId");
            p.addValue("adminId", f.adminId());
        }
        if (f.targetUserId() != null) {
            c.add("a.target_user_id = :tuid");
            p.addValue("tuid", f.targetUserId());
        }
        if (f.conversationId() != null) {
            c.add("a.conversation_id = :cid");
            p.addValue("cid", f.conversationId());
        }
        if (f.kind() != null && !f.kind().isBlank()) {
            c.add("a.kind = :kind");
            p.addValue("kind", f.kind().trim().toUpperCase(java.util.Locale.ROOT));
        }
        if (f.from() != null) {
            c.add("a.created_at >= :from");
            p.addValue("from", Timestamp.from(f.from()));
        }
        if (f.to() != null) {
            c.add("a.created_at < :to");
            p.addValue("to", Timestamp.from(f.to()));
        }
        if (f.q() != null && !f.q().isBlank()) {
            c.add("a.reason ILIKE :q ESCAPE '\\'");
            p.addValue("q", "%" + UserFilter.escapeLike(f.q().trim()) + "%");
        }
        return c.isEmpty() ? "TRUE" : String.join(" AND ", c);
    }

    public long count(Filter f) {
        MapSqlParameterSource p = new MapSqlParameterSource();
        Long n = jdbc.queryForObject("SELECT count(*) FROM message_access_audit a WHERE " + where(f, p), p, Long.class);
        return n == null ? 0 : n;
    }

    /** En yeni önce. */
    public List<MessageAccessRow> page(Filter f, int page, int size) {
        MapSqlParameterSource p = new MapSqlParameterSource();
        String w = where(f, p);
        p.addValue("lim", size).addValue("off", (long) page * size);
        return jdbc.query("SELECT a.id, a.admin_id, u.email AS admin_email, a.conversation_id, a.target_user_id, a.kind, "
                + "a.message_count, a.from_message_id, a.to_message_id, a.reason, a.ip, a.created_at "
                + "FROM message_access_audit a LEFT JOIN app_user u ON u.id = a.admin_id WHERE " + w
                + " ORDER BY a.id DESC LIMIT :lim OFFSET :off", p, (rs, i) -> {
                    long tu = rs.getLong("target_user_id");
                    Long target = rs.wasNull() ? null : tu;
                    long from = rs.getLong("from_message_id");
                    Long fromId = rs.wasNull() ? null : from;
                    long to = rs.getLong("to_message_id");
                    Long toId = rs.wasNull() ? null : to;
                    return new MessageAccessRow(rs.getLong("id"), rs.getLong("admin_id"), rs.getString("admin_email"),
                            rs.getLong("conversation_id"), target, rs.getString("kind"), rs.getInt("message_count"),
                            fromId, toId, rs.getString("reason"), rs.getString("ip"),
                            AdminUserRepository.ts(rs, "created_at"));
                });
    }
}
