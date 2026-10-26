package edu.bingol.backend.messaging;

import edu.bingol.backend.crypto.MessageReader;
import edu.bingol.backend.crypto.Sealed;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Yonetici cozme icin sifreli satirlari okur (gizlenmis mesajlar dahil). Yalnizca sifreli satirlar doner;
 * gecis surerken kalan duz metin satirlar atlanir (docs/ENCRYPTION.md &sect;8.2).
 */
@Component
public class MessageStoreReader implements MessageReader {

    private final JdbcTemplate jdbc;

    public MessageStoreReader(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public List<SealedMessage> read(long conversationId, long fromMessageId, long toMessageId, int limit) {
        return jdbc.query("SELECT id, sender_id, client_id, created_at, body_ciphertext, body_nonce, key_version "
                        + "FROM message WHERE conversation_id = ? AND id BETWEEN ? AND ? AND body_ciphertext IS NOT NULL "
                        + "ORDER BY id LIMIT ?",
                (rs, i) -> new SealedMessage(rs.getLong("id"), rs.getLong("sender_id"),
                        rs.getTimestamp("created_at").toInstant(),
                        MessageCodec.context(rs.getLong("sender_id"), rs.getString("client_id")),
                        new Sealed(rs.getBytes("body_ciphertext"), rs.getBytes("body_nonce"), rs.getInt("key_version"))),
                conversationId, fromMessageId, toMessageId, limit);
    }
}
