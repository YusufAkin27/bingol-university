package edu.bingol.backend.crypto;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

/** JDBC uygulamasi (JPA entity'si yok: ham anahtar baytlari ORM'e girmesin). */
@Repository
public class JdbcConversationKeyStore implements ConversationKeyStore {

    private static final String COLS = "conversation_id, key_version, wrapped_key, master_key_id, active";
    private static final RowMapper<StoredKey> MAPPER = (rs, i) -> new StoredKey(
            rs.getLong("conversation_id"), rs.getInt("key_version"), rs.getBytes("wrapped_key"),
            rs.getString("master_key_id"), rs.getBoolean("active"));

    private final JdbcTemplate jdbc;

    public JdbcConversationKeyStore(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public Optional<StoredKey> find(long conversationId, int version) {
        return jdbc.query("SELECT " + COLS + " FROM conversation_key WHERE conversation_id = ? AND key_version = ?",
                MAPPER, conversationId, version).stream().findFirst();
    }

    @Override
    public Optional<StoredKey> findActive(long conversationId) {
        return jdbc.query("SELECT " + COLS + " FROM conversation_key WHERE conversation_id = ? AND active = TRUE "
                + "ORDER BY key_version DESC LIMIT 1", MAPPER, conversationId).stream().findFirst();
    }

    @Override
    public boolean insert(StoredKey k) {
        // ON CONFLICT: acik bir islemde istisna islemi bozmasin diye cakismayi sayiyla bildirir.
        return jdbc.update("INSERT INTO conversation_key (" + COLS + ") VALUES (?, ?, ?, ?, ?) ON CONFLICT DO NOTHING",
                k.conversationId(), k.version(), k.wrapped(), k.masterKeyId(), k.active()) == 1;
    }

    @Override
    public List<StoredKey> pageNotWrappedBy(String masterKeyId, long afterConversationId, int afterVersion, int limit) {
        return jdbc.query("SELECT " + COLS + " FROM conversation_key WHERE master_key_id <> ? "
                        + "AND (conversation_id > ? OR (conversation_id = ? AND key_version > ?)) "
                        + "ORDER BY conversation_id, key_version LIMIT ?",
                MAPPER, masterKeyId, afterConversationId, afterConversationId, afterVersion, limit);
    }

    @Override
    public boolean rewrap(long conversationId, int version, String oldKeyId, String newKeyId, byte[] newWrapped) {
        return jdbc.update("UPDATE conversation_key SET wrapped_key = ?, master_key_id = ? "
                        + "WHERE conversation_id = ? AND key_version = ? AND master_key_id = ?",
                newWrapped, newKeyId, conversationId, version, oldKeyId) == 1;
    }

    @Override
    public Map<String, Long> countsByMasterKey() {
        Map<String, Long> m = new LinkedHashMap<>();
        jdbc.query("SELECT master_key_id, COUNT(*) AS n FROM conversation_key GROUP BY master_key_id ORDER BY master_key_id",
                rs -> {
                    m.put(rs.getString("master_key_id"), rs.getLong("n"));
                });
        return m;
    }
}
