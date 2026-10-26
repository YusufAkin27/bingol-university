package edu.bingol.backend.crypto;

import java.sql.PreparedStatement;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

/**
 * `message_access_audit`: yalnizca-ekleme. UPDATE/DELETE/TRUNCATE veritabani tetikleyicisiyle
 * engellidir (V68); bu sinif de yalnizca insert sunar.
 */
@Repository
public class MessageAccessAuditRepository {

    private final JdbcTemplate jdbc;

    public MessageAccessAuditRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public long insert(long adminId, long conversationId, int messageCount, Long fromId, Long toId,
                       String reason, String ip) {
        KeyHolder kh = new GeneratedKeyHolder();
        jdbc.update(con -> {
            PreparedStatement ps = con.prepareStatement(
                    "INSERT INTO message_access_audit (admin_id, conversation_id, message_count, from_message_id, "
                            + "to_message_id, reason, ip) VALUES (?, ?, ?, ?, ?, ?, ?)", new String[] {"id"});
            ps.setLong(1, adminId);
            ps.setLong(2, conversationId);
            ps.setInt(3, messageCount);
            ps.setObject(4, fromId);
            ps.setObject(5, toId);
            ps.setString(6, reason);
            ps.setString(7, ip);
            return ps;
        }, kh);
        Number key = kh.getKey();
        return key == null ? -1 : key.longValue();
    }
}
