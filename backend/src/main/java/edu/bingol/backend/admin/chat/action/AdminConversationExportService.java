package edu.bingol.backend.admin.chat.action;

import edu.bingol.backend.admin.Csv;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.ConversationExport;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.CsvExport;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.ExportMessage;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.crypto.AdminDecryptService;
import edu.bingol.backend.crypto.AdminDecryptService.Plain;
import edu.bingol.backend.crypto.MessageAccessAuditRepository.Entry;
import edu.bingol.backend.crypto.Sealed;
import edu.bingol.backend.messaging.MessageCodec;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Yasal talep icin sohbet icerigi disa aktarimi (P08). Kurallar: yonetici sifre cozme acik; sebep en az {@value #MIN_REASON}
 * karakter; ikinci onay (`X-Admin-Confirm` = sohbet kimligi) zorunlu; her istekte degistirilemez {@code message_access_audit}
 * kaydi (tur EXPORT) icerik donmeden ONCE yazilir (yazilamazsa 503 ve icerik donmez). Ayrica istek {@code admin_audit}'e yazilir
 * (controller {@code @AuditRead}). En cok {@value #MAX_MESSAGES} mesaj; fazlasi icin `afterId` ile devam edilir.
 * CSV hucreleri formul enjeksiyonuna karsi kacirilir ({@link Csv}).
 */
@Service
public class AdminConversationExportService {

    public static final int MIN_REASON = 20;
    public static final int MAX_MESSAGES = 5000;
    /** Sorgu parcasi: SQL parametre/bellek sinirlarini asmamak icin gonderen sorgusu bu boyutta bolunur. */
    private static final int ID_CHUNK = 500;

    private final JdbcTemplate jdbc;
    private final NamedParameterJdbcTemplate named;
    private final AdminDecryptService crypto;

    public AdminConversationExportService(JdbcTemplate jdbc, AdminDecryptService crypto) {
        this.jdbc = jdbc;
        this.named = new NamedParameterJdbcTemplate(jdbc);
        this.crypto = crypto;
    }

    private record Raw(long id, long senderId, String clientId, Instant createdAt, Sealed sealed, Long replyTo,
                       Instant editedAt, Instant deletedAt, boolean hidden, boolean adminHidden, boolean purged) {}

    private record Loaded(String type, String title, List<ExportMessage> messages, boolean truncated, Long nextAfterId,
                          Long from, Long to) {}

    public ConversationExport exportJson(long adminId, long conversationId, String reason, String confirm, Long afterId,
                                         String ip) {
        Loaded l = prepare(adminId, conversationId, reason, confirm, afterId, ip);
        return new ConversationExport(conversationId, l.type(), l.title(), Instant.now().toString(), adminId,
                reason.strip(), l.messages().size(), l.truncated(), l.nextAfterId(), l.messages());
    }

    public CsvExport exportCsv(long adminId, long conversationId, String reason, String confirm, Long afterId,
                               String ip) {
        Loaded l = prepare(adminId, conversationId, reason, confirm, afterId, ip);
        StringBuilder sb = new StringBuilder(Csv.BOM);
        sb.append(Csv.row(List.of("id", "createdAt", "senderId", "senderName", "senderEmail", "status", "text",
                "decryptError", "editedAt", "replyToMessageId", "deletedAt")));
        for (ExportMessage m : l.messages()) {
            sb.append(Csv.row(java.util.Arrays.asList(m.id(), m.createdAt(), m.senderId(), m.senderName(),
                    m.senderEmail(), m.status(), m.text(), m.decryptError(), m.editedAt(), m.replyToMessageId(),
                    m.deletedAt())));
        }
        return new CsvExport(sb.toString(), l.messages().size(), l.truncated(), l.nextAfterId());
    }

    /** Dogrulama -> yukleme -> cozme -> DENETIM -> icerigi dondur. */
    private Loaded prepare(long adminId, long conversationId, String reason, String confirm, Long afterId, String ip) {
        crypto.requireEnabled();
        if (reason == null || reason.strip().length() < MIN_REASON) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "REASON_REQUIRED",
                    "Bu işlem için gerekçe zorunludur (en az " + MIN_REASON + " karakter).", String.valueOf(MIN_REASON));
        }
        if (confirm == null || !confirm.strip().equals(String.valueOf(conversationId))) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EXPORT_CONFIRM_REQUIRED",
                    "Dışa aktarma için sohbet kimliğiyle ikinci onay gerekir.");
        }
        List<String[]> conv = jdbc.query("SELECT type, title FROM conversation WHERE id = ?",
                (rs, i) -> new String[] {rs.getString("type"), rs.getString("title")}, conversationId);
        if (conv.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı.");
        }
        long after = afterId == null ? 0 : Math.max(0, afterId);
        List<Raw> raws = new ArrayList<>(jdbc.query("SELECT id, sender_id, client_id, created_at, body_ciphertext, "
                + "body_nonce, key_version, reply_to_message_id, edited_at, deleted_at, hidden_at, admin_hidden_at, "
                + "purged_at FROM message WHERE conversation_id = ? AND id > ? ORDER BY id ASC LIMIT ?",
                (rs, i) -> raw(rs), conversationId, after, MAX_MESSAGES + 1));
        boolean truncated = raws.size() > MAX_MESSAGES;
        if (truncated) {
            raws = new ArrayList<>(raws.subList(0, MAX_MESSAGES));
        }
        Map<Long, String[]> people = people(raws.stream().map(Raw::senderId).collect(Collectors.toSet()));
        List<ExportMessage> out = new ArrayList<>();
        for (Raw r : raws) {
            Plain p = r.purged() ? new Plain(null, null)
                    : crypto.open(conversationId, MessageCodec.context(r.senderId(), r.clientId()), r.sealed());
            String[] who = people.get(r.senderId());
            out.add(new ExportMessage(r.id(), r.createdAt().toString(), r.senderId(), who == null ? null : who[0],
                    who == null ? null : AdminConversationActionService.maskEmail(who[1]), p.text(), p.error(),
                    status(r), r.editedAt() == null ? null : r.editedAt().toString(), r.replyTo(),
                    r.deletedAt() == null ? null : r.deletedAt().toString()));
        }
        Long from = raws.isEmpty() ? null : raws.get(0).id();
        Long to = raws.isEmpty() ? null : raws.get(raws.size() - 1).id();
        // Once degistirilemez denetim kaydi, sonra icerik (yazilamazsa CRYPTO_UNAVAILABLE ve icerik donmez)
        crypto.record(List.of(new Entry(adminId, null, conversationId, out.size(), from, to, reason.strip(), ip, "EXPORT")),
                ip);
        return new Loaded(conv.get(0)[0], conv.get(0)[1], out, truncated, truncated ? to : null, from, to);
    }

    private static Raw raw(java.sql.ResultSet rs) throws java.sql.SQLException {
        byte[] ct = rs.getBytes("body_ciphertext");
        byte[] nonce = rs.getBytes("body_nonce");
        Sealed sealed = ct == null || nonce == null ? null : new Sealed(ct, nonce, rs.getInt("key_version"));
        long reply = rs.getLong("reply_to_message_id");
        boolean replyNull = rs.wasNull();
        return new Raw(rs.getLong("id"), rs.getLong("sender_id"), rs.getString("client_id"),
                rs.getTimestamp("created_at").toInstant(), sealed, replyNull ? null : reply,
                instant(rs.getTimestamp("edited_at")), instant(rs.getTimestamp("deleted_at")),
                rs.getTimestamp("hidden_at") != null, rs.getTimestamp("admin_hidden_at") != null,
                rs.getTimestamp("purged_at") != null);
    }

    private static Instant instant(Timestamp t) {
        return t == null ? null : t.toInstant();
    }

    private static String status(Raw r) {
        if (r.purged()) {
            return "PURGED";
        }
        if (r.deletedAt() != null) {
            return "DELETED";
        }
        if (r.adminHidden()) {
            return "ADMIN_HIDDEN";
        }
        return r.hidden() ? "HIDDEN" : "VISIBLE";
    }

    /** Gonderen id -> {gorunen ad, e-posta}; parca parca sorgulanir. */
    private Map<Long, String[]> people(Set<Long> ids) {
        Map<Long, String[]> out = new HashMap<>();
        List<Long> all = new ArrayList<>(ids);
        for (int i = 0; i < all.size(); i += ID_CHUNK) {
            List<Long> part = all.subList(i, Math.min(all.size(), i + ID_CHUNK));
            named.query("SELECT id, display_name, email FROM app_user WHERE id IN (:ids)",
                    new MapSqlParameterSource("ids", part), rs -> {
                        out.put(rs.getLong("id"), new String[] {rs.getString("display_name"), rs.getString("email")});
                    });
        }
        return out;
    }
}
