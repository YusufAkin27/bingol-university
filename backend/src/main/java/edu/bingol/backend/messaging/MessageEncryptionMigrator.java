package edu.bingol.backend.messaging;

import edu.bingol.backend.crypto.CryptoException;
import edu.bingol.backend.crypto.MessageCipher;
import edu.bingol.backend.crypto.Sealed;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Duz metin mesajlari uygulama icinde, cevrimici ve idempotent sifreler (docs/ENCRYPTION.md &sect;8.3).
 * Her parti kendi transaction'inda `FOR UPDATE SKIP LOCKED` ile satir alir (cok sunucu guvenli); yarida kesilirse
 * kaldigi yerden surer. Sifreleme sonrasi `body` sutunu (varsayilan) NULL'lanir. Biten is bos sorgudan baska is yapmaz.
 */
@Component
public class MessageEncryptionMigrator {

    private static final Logger log = LoggerFactory.getLogger(MessageEncryptionMigrator.class);
    static final int BATCH = 200;

    private final JdbcTemplate jdbc;
    private final MessageCipher cipher;
    private final MessageCodec codec;
    private final TransactionTemplate tx;
    private final boolean enabled;
    private final boolean nullPlaintext;

    public MessageEncryptionMigrator(JdbcTemplate jdbc, MessageCipher cipher, MessageCodec codec,
                                     PlatformTransactionManager txManager,
                                     @Value("${app.crypto.migrate-messages:true}") boolean enabled,
                                     @Value("${app.crypto.null-plaintext-after-encrypt:true}") boolean nullPlaintext) {
        this.jdbc = jdbc;
        this.cipher = cipher;
        this.codec = codec;
        this.tx = new TransactionTemplate(txManager);
        this.enabled = enabled;
        this.nullPlaintext = nullPlaintext;
    }

    @Scheduled(initialDelayString = "${app.crypto.migrate-initial-delay-ms:15000}",
            fixedDelayString = "${app.crypto.migrate-interval-ms:60000}")
    public void scheduled() {
        if (!enabled) {
            return;
        }
        try {
            int n = migrateAll();
            if (n > 0) {
                log.info("Mesaj sifreleme gecisi: {} mesaj sifrelendi", n);
            }
        } catch (RuntimeException e) {
            // Anahtar yoksa vb.: mesajlar duz kalir, sonraki turda yeniden denenir (icerik loglanmaz).
            log.warn("Mesaj sifreleme gecisi durdu: {}", e.toString());
        }
    }

    /** Kalan duz metin satir kalmayana dek parti parti calisir; sifrelenen toplam sayiyi doner. */
    public int migrateAll() {
        if (!codec.legacyColumnPresent()) {
            return 0; // V69_1 uygulanmis: duz metin sutunu yok
        }
        int total = 0;
        while (true) {
            Integer n = tx.execute(s -> migrateBatch());
            if (n == null || n == 0) {
                return total;
            }
            total += n;
        }
    }

    private int migrateBatch() {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT id, conversation_id, sender_id, client_id, body FROM message "
                        + "WHERE body_ciphertext IS NULL AND body IS NOT NULL ORDER BY id LIMIT " + BATCH
                        + " FOR UPDATE SKIP LOCKED");
        for (Map<String, Object> r : rows) {
            long id = ((Number) r.get("id")).longValue();
            long cid = ((Number) r.get("conversation_id")).longValue();
            long sender = ((Number) r.get("sender_id")).longValue();
            Sealed s;
            try {
                s = cipher.encryptText(cid, MessageCodec.context(sender, (String) r.get("client_id")), (String) r.get("body"));
            } catch (CryptoException e) {
                throw new IllegalStateException("sifreleme basarisiz: " + e.reason(), e); // parti geri alinir
            }
            jdbc.update("UPDATE message SET body_ciphertext = ?, body_nonce = ?, key_version = ?"
                            + (nullPlaintext ? ", body = NULL" : "") + " WHERE id = ? AND body_ciphertext IS NULL",
                    s.ciphertext(), s.nonce(), s.keyVersion(), id);
        }
        return rows.size();
    }

    /** Hala sifrelenmemis satir sayisi (izleme/betik icin). */
    public long remaining() {
        if (!codec.legacyColumnPresent()) {
            return 0;
        }
        Long n = jdbc.queryForObject("SELECT COUNT(*) FROM message WHERE body_ciphertext IS NULL AND body IS NOT NULL", Long.class);
        return n == null ? 0 : n;
    }
}
