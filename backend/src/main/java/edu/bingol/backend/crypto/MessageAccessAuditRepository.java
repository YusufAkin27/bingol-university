package edu.bingol.backend.crypto;

import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * `message_access_audit`: yalnizca-ekleme. UPDATE/DELETE/TRUNCATE veritabani tetikleyicisiyle
 * engellidir (V68); bu sinif de yalnizca insert sunar.
 */
@Repository
public class MessageAccessAuditRepository {

    /** Tek erisim kaydi; targetUserId/kind eski kayitlarda null olabilir. */
    public record Entry(long adminId, Long targetUserId, long conversationId, int messageCount, Long fromId, Long toId,
                        String reason, String ip, String kind) {}

    private static final String SQL = "INSERT INTO message_access_audit (admin_id, conversation_id, message_count, "
            + "from_message_id, to_message_id, reason, ip, target_user_id, kind) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";

    private final JdbcTemplate jdbc;

    public MessageAccessAuditRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Kayitlari tek batch'te yazar (liste sayfasi: onizlemesi cozulen her konusma icin bir kayit). */
    public void insertAll(List<Entry> entries) {
        if (entries.isEmpty()) {
            return;
        }
        jdbc.batchUpdate(SQL, entries, entries.size(), (ps, e) -> bind(ps, e));
    }

    private static void bind(PreparedStatement ps, Entry e) throws SQLException {
        ps.setLong(1, e.adminId());
        ps.setLong(2, e.conversationId());
        ps.setInt(3, e.messageCount());
        ps.setObject(4, e.fromId());
        ps.setObject(5, e.toId());
        ps.setString(6, e.reason());
        ps.setString(7, e.ip());
        ps.setObject(8, e.targetUserId());
        ps.setString(9, e.kind());
    }
}
