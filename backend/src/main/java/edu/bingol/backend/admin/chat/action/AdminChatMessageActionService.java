package edu.bingol.backend.admin.chat.action;

import edu.bingol.backend.admin.chat.action.ChatActionDtos.BulkItem;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.BulkResult;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.MessageActionResult;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageEvent;
import edu.bingol.backend.messaging.media.MessageAttachmentService;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici mesaj mudahalesi (P08): gizle / geri goster / kalici sil / toplu gizle. Sebep controller + {@code AdminGuardInterceptor}
 * tarafindan zorlanir; servis yine de bos sebebi reddeder.
 *
 * <p>Gizleme: {@code hidden_at} (var olan tum gizli-mesaj yollari) + {@code admin_hidden_at} (yonetici kaynakli, geri alinabilir
 * isareti) birlikte yazilir; icerik SILINMEZ. Moderasyon gizlemesi (rapor karari) ya da "herkes icin sil" ile cakismaz:
 * zaten gizli/silinmis mesaj 409 MESSAGE_ALREADY_HIDDEN; geri gosterme yalniz yonetici gizlemesini kaldirir.
 * Kalici silme: sifreli govde, duzenleme gecmisi, tepkiler ve ekler temizlenir; satir yer tutucu olarak kalir, GERI ALINAMAZ.
 */
@Service
public class AdminChatMessageActionService {

    public static final int MAX_BULK = 200;
    static final int MIN_REASON = 5;
    private static final Logger log = LoggerFactory.getLogger(AdminChatMessageActionService.class);

    private final JdbcTemplate jdbc;
    private final ChatEventBus bus;
    private final ObjectProvider<MessageAttachmentService> attachments;
    private volatile Boolean legacyBody;

    public AdminChatMessageActionService(JdbcTemplate jdbc, ChatEventBus bus,
                                         ObjectProvider<MessageAttachmentService> attachments) {
        this.jdbc = jdbc;
        this.bus = bus;
        this.attachments = attachments;
    }

    private record Row(long id, long conversationId, boolean hidden, boolean adminHidden, boolean deleted, boolean purged) {}

    // --- tekil ---

    @Transactional
    public MessageActionResult hide(long adminId, long messageId, String reason) {
        requireReason(reason, MIN_REASON);
        Row r = load(messageId);
        if (r.purged()) {
            throw new ApiException(HttpStatus.CONFLICT, "MESSAGE_ALREADY_PURGED", "Bu mesaj kalıcı olarak silindi.");
        }
        Timestamp now = Timestamp.from(Instant.now());
        int n = jdbc.update("UPDATE message SET hidden_at = ?, admin_hidden_at = ?, admin_hidden_by = ? "
                + "WHERE id = ? AND hidden_at IS NULL AND deleted_at IS NULL AND purged_at IS NULL",
                now, now, adminId, messageId);
        if (n == 0) {
            throw alreadyHidden();
        }
        publishRemoved(r.conversationId(), adminId, messageId, now.toInstant());
        return new MessageActionResult(messageId, r.conversationId(), "HIDDEN", false);
    }

    @Transactional
    public MessageActionResult unhide(long adminId, long messageId, String reason) {
        requireReason(reason, MIN_REASON);
        Row r = load(messageId);
        if (r.purged()) {
            throw new ApiException(HttpStatus.CONFLICT, "MESSAGE_ALREADY_PURGED", "Bu mesaj kalıcı olarak silindi.");
        }
        int n = jdbc.update("UPDATE message SET hidden_at = NULL, admin_hidden_at = NULL, admin_hidden_by = NULL "
                + "WHERE id = ? AND admin_hidden_at IS NOT NULL AND purged_at IS NULL", messageId);
        if (n == 0) {
            // moderasyon gizlemesi ya da hic gizli degil: yonetici buradan geri aciamaz
            throw new ApiException(HttpStatus.CONFLICT, "MESSAGE_NOT_ADMIN_HIDDEN",
                    "Bu mesaj yönetici tarafından gizlenmedi; geri gösterilemez.");
        }
        return new MessageActionResult(messageId, r.conversationId(), "VISIBLE", false);
    }

    /** Kalici silme: icerik temizlenir, yer tutucu kalir. GERI ALINAMAZ (irreversible). Sebep en az 10 karakter. */
    @Transactional
    public MessageActionResult purge(long adminId, long messageId, String reason) {
        requireReason(reason, 10);
        Row r = load(messageId);
        if (r.purged()) {
            throw new ApiException(HttpStatus.CONFLICT, "MESSAGE_ALREADY_PURGED", "Bu mesaj kalıcı olarak silindi.");
        }
        Timestamp now = Timestamp.from(Instant.now());
        int n = jdbc.update("UPDATE message SET body_ciphertext = NULL, body_nonce = NULL, key_version = NULL, "
                + "purged_at = ?, deleted_at = COALESCE(deleted_at, ?), deleted_by = COALESCE(deleted_by, ?) "
                + "WHERE id = ? AND purged_at IS NULL", now, now, adminId, messageId);
        if (n == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "MESSAGE_ALREADY_PURGED", "Bu mesaj kalıcı olarak silindi.");
        }
        if (legacyBodyColumn()) {
            jdbc.update("UPDATE message SET body = NULL WHERE id = ? AND body IS NOT NULL", messageId);
        }
        jdbc.update("DELETE FROM message_revision WHERE message_id = ?", messageId);
        jdbc.update("DELETE FROM message_reaction WHERE message_id = ?", messageId);
        MessageAttachmentService media = attachments.getIfAvailable();
        if (media != null) {
            media.purgeForMessage(messageId); // hata mesaj basina yutulur (servis kendi icinde loglar)
        }
        publishRemoved(r.conversationId(), adminId, messageId, now.toInstant());
        return new MessageActionResult(messageId, r.conversationId(), "PURGED", true);
    }

    // --- toplu ---

    /**
     * Toplu gizleme (en cok {@value #MAX_BULK}). Her mesaj kendi islemiyle calisir; biri hata verse digerleri etkilenmez
     * (kismi basari raporu). Bu sinif bilerek sinif duzeyinde @Transactional DEGILDIR (bir hata partiyi rollback-only yapardi).
     */
    public BulkResult bulkHide(long adminId, List<Long> rawIds, String reason, BulkAudit audit) {
        requireReason(reason, MIN_REASON);
        LinkedHashSet<Long> ids = new LinkedHashSet<>();
        if (rawIds != null) {
            for (Long id : rawIds) {
                if (id != null && id > 0) {
                    ids.add(id);
                }
            }
        }
        if (ids.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
        if (ids.size() > MAX_BULK) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CHAT_BULK_LIMIT",
                    "Tek seferde en fazla " + MAX_BULK + " mesaj işlenebilir.", String.valueOf(MAX_BULK));
        }
        List<BulkItem> items = new ArrayList<>();
        int done = 0;
        for (Long id : ids) {
            BulkItem item;
            try {
                hide(adminId, id, reason);
                item = new BulkItem(id, true, HttpStatus.OK.value(), null);
                done++;
            } catch (ApiException ex) {
                item = new BulkItem(id, false, ex.status().value(), ex.code());
            } catch (RuntimeException ex) {
                log.warn("Toplu mesaj gizleme beklenmeyen hata: id={} {}", id, ex.toString());
                item = new BulkItem(id, false, HttpStatus.INTERNAL_SERVER_ERROR.value(), "INTERNAL_ERROR");
            }
            items.add(item);
        }
        if (audit != null) {
            audit.items(reason, items);
        }
        return new BulkResult(ids.size(), done, ids.size() - done, items);
    }

    /** Toplu islemde mesaj basina denetim satiri (istegin kendi satirina ek). */
    public interface BulkAudit {
        void items(String reason, List<BulkItem> items);
    }

    // --- yardimcilar ---

    private Row load(long messageId) {
        List<Row> rows = jdbc.query("SELECT id, conversation_id, hidden_at, admin_hidden_at, deleted_at, purged_at "
                + "FROM message WHERE id = ?", (rs, i) -> new Row(rs.getLong("id"), rs.getLong("conversation_id"),
                rs.getTimestamp("hidden_at") != null, rs.getTimestamp("admin_hidden_at") != null,
                rs.getTimestamp("deleted_at") != null, rs.getTimestamp("purged_at") != null), messageId);
        if (rows.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "MESSAGE_NOT_FOUND", "Mesaj bulunamadı.");
        }
        return rows.get(0);
    }

    static void requireReason(String reason, int min) {
        if (reason == null || reason.strip().length() < min) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_REQUIRED",
                    "Bu işlem için gerekçe zorunludur (en az " + min + " karakter).", String.valueOf(min));
        }
    }

    private static ApiException alreadyHidden() {
        return new ApiException(HttpStatus.CONFLICT, "MESSAGE_ALREADY_HIDDEN",
                "Bu mesaj zaten gizlenmiş ya da silinmiş.");
    }

    /** Eski duz metin sutunu (V69 gecis donemi) hala var mi; kalici silmede de temizlenmeli. */
    private boolean legacyBodyColumn() {
        Boolean v = legacyBody;
        if (v == null) {
            Integer n = jdbc.queryForObject("SELECT COUNT(*) FROM information_schema.columns "
                    + "WHERE lower(table_name) = 'message' AND lower(column_name) = 'body'", Integer.class);
            v = n != null && n > 0;
            legacyBody = v;
        }
        return v;
    }

    /** Aktif uyelere "deleted" olayi (kullanici API'si ayni mesaji yer tutucuyla dondurur); hata eylemi bozmaz. */
    private void publishRemoved(long conversationId, long adminId, long messageId, Instant at) {
        try {
            List<Long> recipients = jdbc.queryForList("SELECT user_id FROM conversation_member "
                    + "WHERE conversation_id = ? AND left_at IS NULL", Long.class, conversationId);
            bus.publish("message-events", recipients,
                    new MessageEvent("deleted", conversationId, messageId, adminId, null, null, null, at.toString()));
        } catch (RuntimeException e) {
            log.warn("Yonetici mesaj olayi yayinlanamadi (mesaj {}): {}", messageId, e.toString());
        }
    }
}
