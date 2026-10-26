package edu.bingol.backend.messaging;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.crypto.CryptoException;
import edu.bingol.backend.crypto.MessageCipher;
import edu.bingol.backend.crypto.Sealed;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Mesaj govdesini sifreleme/cozme icin TEK nokta (docs/ENCRYPTION.md &sect;8). Duz metin yalnizca bellekte
 * ({@link Message#getBody()}, kalici degil) bulunur. AAD baglami = "m1" + gonderen + clientId: mesaj kimligi
 * insert oncesi bilinmedigi icin (konusma, gonderen, clientId) uclusu baglanir; baska mesaja tasinan sifreli metin cozulmez.
 */
@Component
public class MessageCodec {

    private static final Logger log = LoggerFactory.getLogger(MessageCodec.class);
    private static final byte[] VERSION_TAG = "m1".getBytes(StandardCharsets.US_ASCII);

    private final MessageCipher cipher;
    private final JdbcTemplate jdbc;
    private volatile Boolean legacyColumn;

    public MessageCodec(MessageCipher cipher, JdbcTemplate jdbc) {
        this.cipher = cipher;
        this.jdbc = jdbc;
    }

    /** Sifreleme baglami; MessageStoreReader ve yonetici cozme ayni bicimi kullanir. */
    public static byte[] context(Long senderId, String clientId) {
        byte[] c = clientId.getBytes(StandardCharsets.UTF_8);
        return ByteBuffer.allocate(VERSION_TAG.length + 8 + c.length).put(VERSION_TAG).putLong(senderId).put(c).array();
    }

    /** Konusma, gonderen ve clientId dolu olmalidir. Sifreleme yapilamazsa 503 CRYPTO_UNAVAILABLE. */
    public void seal(Message m, String text) {
        try {
            Sealed s = cipher.encryptText(m.getConversationId(), context(m.getSenderId(), m.getClientId()), text);
            m.setBodyCiphertext(s.ciphertext());
            m.setBodyNonce(s.nonce());
            m.setKeyVersion(s.keyVersion());
            m.setBody(text);
        } catch (CryptoException e) {
            log.error("Mesaj sifrelenemedi: konusma={} neden={}", m.getConversationId(), e.reason());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "CRYPTO_UNAVAILABLE",
                    "Şifreleme hizmeti şu anda kullanılamıyor.");
        }
    }

    /** Duz metni belleğe koyar (gizli mesajlar cozulmez). Cozulemezse body null kalir; hata mesaj basina yutulur. */
    public Message open(Message m) {
        if (m.isHidden() || m.isDeleted() || m.getBody() != null) {
            return m;
        }
        if (m.getBodyCiphertext() == null) {
            if (m.getId() != null && legacyColumnPresent()) {
                List<String> r = jdbc.query("SELECT body FROM message WHERE id = ?", (rs, i) -> rs.getString(1), m.getId());
                m.setBody(r.isEmpty() ? null : r.get(0));
            }
            return m;
        }
        try {
            m.setBody(cipher.decryptText(m.getConversationId(), context(m.getSenderId(), m.getClientId()),
                    new Sealed(m.getBodyCiphertext(), m.getBodyNonce(), m.getKeyVersion() == null ? 1 : m.getKeyVersion())));
        } catch (CryptoException e) {
            m.setBody(null); // MessageView "goruntulenemiyor" metnini gosterir; neden/metrik EnvelopeMessageCipher'da
        }
        return m;
    }

    public List<Message> openAll(List<Message> list) {
        list.forEach(this::open);
        return list;
    }

    /** Gecis donemi: eski `body` sutunu hala var mi (V69_1 ile dusurulur). */
    boolean legacyColumnPresent() {
        Boolean v = legacyColumn;
        if (v == null) {
            Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM information_schema.columns "
                    + "WHERE lower(table_name) = 'message' AND lower(column_name) = 'body'", Integer.class);
            v = n != null && n > 0;
            legacyColumn = v;
        }
        return v;
    }
}
