package edu.bingol.backend.admin.chat.action;

import edu.bingol.backend.admin.chat.action.ChatActionDtos.ConversationMeta;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.ConversationStateResult;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.MemberMeta;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.MemberRemoval;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici sohbet/oda mudahalesi (P08): kapat / yeniden ac, uyeyi gruptan cikar, ust veri (ICERIK YOK).
 * Kapatma yalniz yeni mesaj gonderimini engeller (`MessageService` 409 CONVERSATION_CLOSED); uyelikler ve gecmis korunur.
 * Kulup/etkinlik odasinda uyelik kaynaga baglidir: buradan cikarma 409 CONVERSATION_ROOM_MANAGED (kulup/etkinlik uyeligi
 * yonetim ekranindan yonetilir; aksi halde oda senkronu uyeyi geri eklerdi).
 */
@Service
public class AdminConversationActionService {

    public static final int MAX_MEMBERS_LISTED = 200;
    /** Bildirim gonderilecek en cok uye (oda ust siniri app.chat.room-max-members varsayilan 500). */
    static final int MAX_NOTIFIED = 500;
    private static final Logger log = LoggerFactory.getLogger(AdminConversationActionService.class);

    private final JdbcTemplate jdbc;
    private final NotificationService notifications;
    private Executor fanout = Runnable::run;

    public AdminConversationActionService(JdbcTemplate jdbc, NotificationService notifications) {
        this.jdbc = jdbc;
        this.notifications = notifications;
    }

    /** Bildirim dagitimi icin (buyuk odalarda yoneticiyi bekletmesin); varsayilan: cagiran is parcacigi. */
    @Autowired(required = false)
    void setFanout(@Qualifier("chatFanoutExecutor") Executor fanout) {
        this.fanout = fanout;
    }

    private record Conv(long id, String type, String title, boolean closed) {}

    // --- kapat / ac ---

    @Transactional
    public ConversationStateResult close(long adminId, long conversationId, String reason) {
        AdminChatMessageActionService.requireReason(reason, AdminChatMessageActionService.MIN_REASON);
        Conv c = load(conversationId);
        Timestamp now = Timestamp.from(Instant.now());
        String r = reason.strip();
        int n = jdbc.update("UPDATE conversation SET closed_at = ?, closed_by = ?, closed_reason = ? "
                + "WHERE id = ? AND closed_at IS NULL", now, adminId, r.length() > 300 ? r.substring(0, 300) : r,
                conversationId);
        if (n == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "CONVERSATION_ALREADY_CLOSED", "Bu sohbet zaten kapalı.");
        }
        int notified = notifyMembers(conversationId, "notif.chat.closed.title", "notif.chat.closed.body", "CONVERSATION_CLOSED");
        log.info("Yonetici sohbeti kapatti: admin={} sohbet={} tur={}", adminId, c.id(), c.type());
        return new ConversationStateResult(conversationId, true, now.toInstant().toString(), notified);
    }

    @Transactional
    public ConversationStateResult reopen(long adminId, long conversationId, String reason) {
        AdminChatMessageActionService.requireReason(reason, AdminChatMessageActionService.MIN_REASON);
        load(conversationId);
        int n = jdbc.update("UPDATE conversation SET closed_at = NULL, closed_by = NULL, closed_reason = NULL "
                + "WHERE id = ? AND closed_at IS NOT NULL", conversationId);
        if (n == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "CONVERSATION_NOT_CLOSED", "Bu sohbet kapalı değil.");
        }
        int notified = notifyMembers(conversationId, "notif.chat.reopened.title", "notif.chat.reopened.body", "CONVERSATION_REOPENED");
        log.info("Yonetici sohbeti yeniden acti: admin={} sohbet={}", adminId, conversationId);
        return new ConversationStateResult(conversationId, false, null, notified);
    }

    // --- uye cikarma ---

    @Transactional
    public MemberRemoval removeMember(long adminId, long conversationId, long userId, String reason) {
        AdminChatMessageActionService.requireReason(reason, AdminChatMessageActionService.MIN_REASON);
        Conv c = load(conversationId);
        if ("DIRECT".equals(c.type())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "NOT_A_GROUP", "Bu işlem yalnızca gruplarda yapılabilir.");
        }
        Integer linked = jdbc.queryForObject("SELECT COUNT(*) FROM chat_room_link WHERE conversation_id = ?",
                Integer.class, conversationId);
        if (linked != null && linked > 0) {
            throw new ApiException(HttpStatus.CONFLICT, "CONVERSATION_ROOM_MANAGED",
                    "Kulüp/etkinlik odası üyeliği kaynağa bağlıdır; üyelik kulüp/etkinlik yönetiminden değiştirilir.");
        }
        int n = jdbc.update("UPDATE conversation_member SET left_at = ? WHERE conversation_id = ? AND user_id = ? "
                + "AND left_at IS NULL", Timestamp.from(Instant.now()), conversationId, userId);
        if (n == 0) {
            throw new ApiException(HttpStatus.NOT_FOUND, "MEMBER_NOT_FOUND", "Üye bulunamadı.");
        }
        promoteIfNoAdmin(conversationId);
        notifyOne(userId, "notif.chat.removed.title", "notif.chat.removed.body", conversationId, "CONVERSATION_REMOVED");
        log.info("Yonetici uyeyi gruptan cikardi: admin={} sohbet={} uye={}", adminId, conversationId, userId);
        return new MemberRemoval(conversationId, userId, true);
    }

    /** Kullanici grubunda yonetici kalmadiysa en eski uye yonetici olur (kullanicinin kendi ayrilmasiyla ayni kural). */
    private void promoteIfNoAdmin(long conversationId) {
        Integer admins = jdbc.queryForObject("SELECT COUNT(*) FROM conversation_member "
                + "WHERE conversation_id = ? AND left_at IS NULL AND role = 'ADMIN'", Integer.class, conversationId);
        if (admins != null && admins == 0) {
            List<Long> oldest = jdbc.queryForList("SELECT id FROM conversation_member WHERE conversation_id = ? "
                    + "AND left_at IS NULL ORDER BY joined_at ASC, id ASC LIMIT 1", Long.class, conversationId);
            if (!oldest.isEmpty()) {
                jdbc.update("UPDATE conversation_member SET role = 'ADMIN' WHERE id = ?", oldest.get(0));
            }
        }
    }

    // --- ust veri ---

    /** Sohbet ust verisi: tur, uyeler (e-posta maskeli), mesaj sayisi, durum, acik rapor sayisi. ICERIK donmez. */
    public ConversationMeta meta(long conversationId) {
        List<Object[]> rows = jdbc.query("SELECT id, type, title, closed_at, closed_by, closed_reason, created_at, "
                + "last_message_at FROM conversation WHERE id = ?", (rs, i) -> new Object[] {rs.getLong("id"),
                rs.getString("type"), rs.getString("title"), rs.getTimestamp("closed_at"),
                (Long) rs.getObject("closed_by"), rs.getString("closed_reason"), rs.getTimestamp("created_at"),
                rs.getTimestamp("last_message_at")}, conversationId);
        if (rows.isEmpty()) {
            throw notFound();
        }
        Object[] r = rows.get(0);
        String type = (String) r[1];
        Timestamp closedAt = (Timestamp) r[3];

        String kind = type;
        Long communityId = null;
        Long eventId = null;
        List<Object[]> link = jdbc.query("SELECT kind, ref_id FROM chat_room_link WHERE conversation_id = ?",
                (rs, i) -> new Object[] {rs.getString("kind"), rs.getLong("ref_id")}, conversationId);
        boolean managed = !link.isEmpty();
        if (managed) {
            String k = (String) link.get(0)[0];
            kind = "COMMUNITY".equals(k) ? "CLUB" : "EVENT";
            if ("CLUB".equals(kind)) {
                communityId = (Long) link.get(0)[1];
            } else {
                eventId = (Long) link.get(0)[1];
            }
        }
        Long messages = jdbc.queryForObject("SELECT COUNT(*) FROM message WHERE conversation_id = ?", Long.class,
                conversationId);
        Integer active = jdbc.queryForObject("SELECT COUNT(*) FROM conversation_member "
                + "WHERE conversation_id = ? AND left_at IS NULL", Integer.class, conversationId);
        Integer reports = jdbc.queryForObject("SELECT COUNT(*) FROM report r JOIN message m ON m.id = r.target_id "
                + "WHERE r.target_type = 'MESSAGE' AND r.status = 'OPEN' AND m.conversation_id = ?", Integer.class,
                conversationId);
        // Aktifler once, en eski katilan once; en cok MAX_MEMBERS_LISTED kayit
        List<MemberMeta> members = new ArrayList<>(jdbc.query("SELECT cm.user_id, cm.role, cm.joined_at, cm.left_at, "
                + "u.display_name, u.email FROM conversation_member cm LEFT JOIN app_user u ON u.id = cm.user_id "
                + "WHERE cm.conversation_id = ? ORDER BY CASE WHEN cm.left_at IS NULL THEN 0 ELSE 1 END, cm.joined_at, "
                + "cm.id LIMIT ?", (rs, i) -> new MemberMeta(rs.getLong("user_id"), rs.getString("display_name"),
                maskEmail(rs.getString("email")), rs.getString("role"), str(rs.getTimestamp("joined_at")),
                str(rs.getTimestamp("left_at")), rs.getTimestamp("left_at") == null), conversationId,
                MAX_MEMBERS_LISTED + 1));
        boolean truncated = members.size() > MAX_MEMBERS_LISTED;
        if (truncated) {
            members = new ArrayList<>(members.subList(0, MAX_MEMBERS_LISTED));
        }
        return new ConversationMeta(conversationId, type, kind, communityId, eventId, (String) r[2], closedAt != null,
                str(closedAt), (Long) r[4], (String) r[5], messages == null ? 0 : messages,
                active == null ? 0 : active, reports == null ? 0 : reports, str((Timestamp) r[6]), str((Timestamp) r[7]),
                managed, truncated, members);
    }

    // --- yardimcilar ---

    private Conv load(long conversationId) {
        List<Conv> rows = jdbc.query("SELECT id, type, title, closed_at FROM conversation WHERE id = ?",
                (rs, i) -> new Conv(rs.getLong("id"), rs.getString("type"), rs.getString("title"),
                        rs.getTimestamp("closed_at") != null), conversationId);
        if (rows.isEmpty()) {
            throw notFound();
        }
        return rows.get(0);
    }

    private static ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "CONVERSATION_NOT_FOUND", "Konuşma bulunamadı.");
    }

    /** "ayse.yilmaz@bingol.edu.tr" -> "a***@bingol.edu.tr". */
    static String maskEmail(String address) {
        if (address == null || address.isBlank()) {
            return null;
        }
        int at = address.lastIndexOf('@');
        if (at <= 0) {
            return "***";
        }
        return address.charAt(0) + "***" + address.substring(at);
    }

    private static String str(Timestamp t) {
        return t == null ? null : t.toInstant().toString();
    }

    /** Aktif uyelere alicinin kayitli dilinde bildirim (hata/kuyruk dolulugu eylemi bozmaz); denenen uye sayisini doner. */
    private int notifyMembers(long conversationId, String titleKey, String bodyKey, String event) {
        List<Long> ids = jdbc.queryForList("SELECT user_id FROM conversation_member WHERE conversation_id = ? "
                + "AND left_at IS NULL ORDER BY id LIMIT ?", Long.class, conversationId, MAX_NOTIFIED);
        try {
            fanout.execute(() -> ids.forEach(id -> notifyOne(id, titleKey, bodyKey, conversationId, event)));
        } catch (RejectedExecutionException e) {
            log.warn("Bildirim kuyrugu dolu, sohbet {} bildirimi atlandi", conversationId);
            return 0;
        }
        return ids.size();
    }

    private void notifyOne(long userId, String titleKey, String bodyKey, long conversationId, String event) {
        try {
            notifications.sendLocalized(userId, NotificationType.SYSTEM, titleKey, bodyKey, null,
                    Map.of("conversationId", String.valueOf(conversationId), "targetType", "CONVERSATION",
                            "targetId", String.valueOf(conversationId), "event", event));
        } catch (RuntimeException e) {
            log.warn("Sohbet bildirimi gonderilemedi (kullanici {}): {}", userId, e.toString());
        }
    }
}
