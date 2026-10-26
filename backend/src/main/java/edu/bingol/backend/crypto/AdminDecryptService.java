package edu.bingol.backend.crypto;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.crypto.MessageReader.SealedMessage;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Yonetici mesaj cozme. Kurallar: ayar acik, gerekce >= 10 karakter, tek istekte en fazla N mesaj,
 * duz metin DONMEDEN ONCE degistirilemez denetim kaydi yazilir (kayit yazilamazsa duz metin verilmez).
 */
@Service
public class AdminDecryptService {

    private static final Logger log = LoggerFactory.getLogger(AdminDecryptService.class);
    public static final int MIN_REASON = 10;
    public static final int MAX_REASON = 500;

    public record Request(Long conversationId, Long fromMessageId, Long toMessageId, String reason) {}

    /** text bos ise cozme basarisizdir (error dolu). */
    public record Item(long id, long senderId, Instant createdAt, String text, String error) {}

    public record Response(long auditId, long conversationId, int count, List<Item> messages) {}

    private final CryptoProperties props;
    private final Optional<MessageReader> reader;
    private final MessageCipher cipher;
    private final MessageAccessAuditRepository audit;

    public AdminDecryptService(CryptoProperties props, Optional<MessageReader> reader, MessageCipher cipher,
                               MessageAccessAuditRepository audit) {
        this.props = props;
        this.reader = reader;
        this.cipher = cipher;
        this.audit = audit;
    }

    public Response decrypt(long adminId, Request req, String ip) {
        if (!props.adminDecryptEnabled()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ADMIN_DECRYPT_DISABLED", "Yönetici mesaj çözme kapalı.");
        }
        String reason = req.reason() == null ? "" : req.reason().trim();
        if (reason.length() < MIN_REASON || reason.length() > MAX_REASON) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "DECRYPT_REASON_REQUIRED",
                    "Gerekçe en az {0} karakter olmalıdır.", String.valueOf(MIN_REASON));
        }
        if (req.conversationId() == null || req.fromMessageId() == null || req.conversationId() < 1
                || req.fromMessageId() < 1) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "DECRYPT_RANGE_INVALID", "Konuşma ve mesaj aralığı geçersiz.");
        }
        long from = req.fromMessageId();
        long to = req.toMessageId() == null ? from : req.toMessageId();
        if (to < from) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "DECRYPT_RANGE_INVALID", "Konuşma ve mesaj aralığı geçersiz.");
        }
        MessageReader r = reader.orElseThrow(() -> new ApiException(HttpStatus.NOT_IMPLEMENTED,
                "MESSAGE_READER_UNAVAILABLE", "Mesaj okuma henüz etkin değil."));

        int max = props.adminDecryptMaxMessages();
        long cid = req.conversationId();
        List<SealedMessage> rows = r.read(cid, from, to, max + 1);
        if (rows.size() > max) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "DECRYPT_TOO_MANY",
                    "Tek istekte en fazla {0} mesaj çözülebilir.", String.valueOf(max));
        }
        List<Item> items = new ArrayList<>(rows.size());
        for (SealedMessage m : rows) {
            try {
                String text = cipher.decryptText(cid, m.contextBytes(), m.sealed());
                items.add(new Item(m.messageId(), m.senderId(), m.createdAt(), text, null));
            } catch (CryptoException e) {
                items.add(new Item(m.messageId(), m.senderId(), m.createdAt(), null, e.reason().name()));
            }
        }
        // Once denetim, sonra duz metin: kayit basarisizsa istisna kalkar ve metin donmez.
        long auditId = audit.insert(adminId, cid, items.size(), from, to, reason, ip);
        log.info("Yonetici mesaj cozdu: admin={} konusma={} adet={} denetim={}", adminId, cid, items.size(), auditId);
        return new Response(auditId, cid, items.size(), items);
    }
}
