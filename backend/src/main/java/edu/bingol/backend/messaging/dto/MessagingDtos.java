package edu.bingol.backend.messaging.dto;

import edu.bingol.backend.messaging.Message;
import edu.bingol.backend.messaging.media.AttachmentView;
import edu.bingol.backend.moderation.ReportReason;
import edu.bingol.backend.user.User;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

public final class MessagingDtos {

    private MessagingDtos() {}

    public static final String REMOVED_TEXT = "Bu mesaj kaldırıldı";
    public static final String UNREADABLE_TEXT = "Bu mesaj görüntülenemiyor";
    public static final String DELETED_TEXT = "Bu mesaj silindi";
    /** P08: yonetici gizlemesi / kalici silmesi yer tutucusu (REMOVED_TEXT moderasyon gizlemesi icindir). */
    public static final String ADMIN_REMOVED_TEXT = "Bu mesaj yönetici tarafından kaldırıldı";
    public static final String BLOCKED_TEXT ="Engellediğiniz kullanıcının mesajı gizlendi";

    // --- istekler ---

    /** `userId` doluysa birebir, degilse `title` + `memberIds` ile grup. */
    public record CreateConversationRequest(Long userId, @Size(max = 100) String title,
                                            @Size(max = 49) List<Long> memberIds) {}

    public record RenameRequest(@NotBlank @Size(max = 100) String title) {}

    public record AddMembersRequest(@NotEmpty @Size(max = 49) List<Long> userIds) {}

    /**
     * `text` duz metindir; bos/yalniz-bosluk ve 2000 karakter siniri serviste kontrol edilir. T8: `attachmentIds`
     * (en fazla 4) doluysa `text` bos olabilir (yalniz gorsel).
     */
    public record SendMessageRequest(String text, @NotBlank @Size(max = 64) String clientId, Long replyToMessageId,
                                     @Size(max = 50) List<Long> attachmentIds, Boolean viewOnce) {
        public SendMessageRequest(String text, String clientId, Long replyToMessageId, List<Long> attachmentIds) {
            this(text, clientId, replyToMessageId, attachmentIds, null);
        }

        public SendMessageRequest(String text, String clientId, Long replyToMessageId) {
            this(text, clientId, replyToMessageId, null, null);
        }
    }

    public record EditMessageRequest(@NotNull String text) {}

    /** `emoji` izinli listeden (app.chat.reactions) olmalidir. */
    public record ReactRequest(@NotBlank @Size(max = 16) String emoji) {}

    /** `durationMinutes` (1..525600) ya da `forever=true`; ikisi birden verilemez. */
    public record MuteRequest(Integer durationMinutes, Boolean forever) {}

    /** `keepArchived` true ise yeni mesaj gelse de arsivde kalir. */
    public record ArchiveRequest(Boolean keepArchived) {}

    public record ReadRequest(@NotNull Long lastMessageId) {}

    /** Iletildi ack'i: `lastMessageId`'ye kadar olan mesajlar bu cihaza ulasti. */
    public record DeliveredRequest(@NotNull Long lastMessageId) {}

    public record ReportMessageRequest(@NotNull ReportReason reason, @Size(max = 500) String note) {}

    // --- yanitlar ---

    /** `online`: yalniz konusma listesindeki birebir karsi tarafta dolu (diger yerlerde null = gonderilmez). */
    /**
     * `department`/`classYear`: yalniz konusma listesindeki birebir karsi tarafta, profil gizlilik ayari bakana izin
     * veriyorsa dolar (yoksa gonderilmez).
     */
    public record UserSummary(Long id, String displayName, String avatarUrl,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Boolean online,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) String department,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Short classYear) {
        public UserSummary(Long id, String displayName, String avatarUrl) {
            this(id, displayName, avatarUrl, null, null, null);
        }

        public static UserSummary of(User u) {
            return new UserSummary(u.getId(), u.getDisplayName(), u.getAvatarUrl(), null, null, null);
        }

        public UserSummary withOnline(boolean value) {
            return new UserSummary(id, displayName, avatarUrl, value, department, classYear);
        }

        public UserSummary withProfile(String dept, Short year) {
            return new UserSummary(id, displayName, avatarUrl, online, dept, year);
        }
    }

    /** Yanitlanan mesajin kisa, cozulmus onizlemesi; `deleted` true ise silinmis/kaldirilmis (metin sabit aciklama). */
    public record ReplyPreview(Long id, Long senderId, String text, boolean deleted) {}

    public record ReactionCount(String emoji, long count) {}

    /**
     * Gizlenen / engelli / silinen kullanicidan gelen mesajlarda `text` sabit bir aciklamadir, `removed` true olur.
     * `deleted`: gonderen/yonetici herkes icin sildi. `edited`: duzenlendi (gecmis surum tutulmaz).
     */
    public record MessageView(Long id, Long conversationId, Long senderId, String clientId, String text,
                              boolean removed, String createdAt, Long replyToMessageId, ReplyPreview replyTo,
                              boolean edited, String editedAt, boolean deleted, List<ReactionCount> reactions,
                              String myReaction, List<AttachmentView> attachments,
                              String status,
                              @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) String senderName) {
        /** `senderName` yalniz konusma listesi onizlemesinde (grup/kulup/etkinlik) dolar; diger yerlerde gonderilmez. */
        public MessageView(Long id, Long conversationId, Long senderId, String clientId, String text,
                           boolean removed, String createdAt, Long replyToMessageId, ReplyPreview replyTo,
                           boolean edited, String editedAt, boolean deleted, List<ReactionCount> reactions,
                           String myReaction, List<AttachmentView> attachments, String status) {
            this(id, conversationId, senderId, clientId, text, removed, createdAt, replyToMessageId, replyTo, edited,
                    editedAt, deleted, reactions, myReaction, attachments, status, null);
        }

        public MessageView(Long id, Long conversationId, Long senderId, String clientId, String text,
                           boolean removed, String createdAt, Long replyToMessageId, ReplyPreview replyTo,
                           boolean edited, String editedAt, boolean deleted, List<ReactionCount> reactions,
                           String myReaction) {
            this(id, conversationId, senderId, clientId, text, removed, createdAt, replyToMessageId, replyTo, edited,
                    editedAt, deleted, reactions, myReaction, List.of(), null);
        }

        public MessageView(Long id, Long conversationId, Long senderId, String clientId, String text,
                           boolean removed, String createdAt, Long replyToMessageId, ReplyPreview replyTo,
                           boolean edited, String editedAt, boolean deleted, List<ReactionCount> reactions,
                           String myReaction, List<AttachmentView> attachments) {
            this(id, conversationId, senderId, clientId, text, removed, createdAt, replyToMessageId, replyTo, edited,
                    editedAt, deleted, reactions, myReaction, attachments, null);
        }

        /** Makbuz durumu (SENT | DELIVERED | READ); yalniz istek sahibinin kendi mesajlarinda dolu. */
        public MessageView withStatus(String s) {
            return new MessageView(id, conversationId, senderId, clientId, text, removed, createdAt, replyToMessageId,
                    replyTo, edited, editedAt, deleted, reactions, myReaction, attachments, s, senderName);
        }

        public MessageView withSenderName(String name) {
            return new MessageView(id, conversationId, senderId, clientId, text, removed, createdAt, replyToMessageId,
                    replyTo, edited, editedAt, deleted, reactions, myReaction, attachments, status, name);
        }

        /** T8: gorsel ekleri ekler (gizlenen/silinen/engelli mesajda ek gosterilmez). */
        public MessageView withAttachments(List<AttachmentView> list) {
            return removed || list == null ? this : new MessageView(id, conversationId, senderId, clientId, text,
                    removed, createdAt, replyToMessageId, replyTo, edited, editedAt, deleted, reactions, myReaction,
                    List.copyOf(list), status, senderName);
        }

        public static MessageView of(Message m) {
            return of(m, false);
        }

        public static MessageView of(Message m, boolean senderBlocked) {
            // Cozulemeyen (anahtar/etiket hatasi) mesaj tum listeyi bozmasin: sabit metinle gosterilir.
            boolean gone = m.isHidden() || m.isDeleted();
            boolean unreadable = !gone && !senderBlocked && m.getBody() == null;
            boolean removed = gone || senderBlocked || unreadable;
            String text = m.isAdminRemoved() ? ADMIN_REMOVED_TEXT : m.isHidden() ? REMOVED_TEXT : m.isDeleted() ? DELETED_TEXT : senderBlocked ? BLOCKED_TEXT
                    : unreadable ? UNREADABLE_TEXT : m.getBody();
            return new MessageView(m.getId(), m.getConversationId(), m.getSenderId(), m.getClientId(), text,
                    removed, m.getCreatedAt().toString(), m.isDeleted() ? null : m.getReplyToMessageId(), null,
                    m.getEditedAt() != null && !m.isDeleted(),
                    m.getEditedAt() == null || m.isDeleted() ? null : m.getEditedAt().toString(), m.isDeleted(),
                    List.of(), null);
        }

        public MessageView withExtras(ReplyPreview reply, List<ReactionCount> counts, String mine) {
            return new MessageView(id, conversationId, senderId, clientId, text, removed, createdAt, replyToMessageId,
                    reply, edited, editedAt, deleted, counts, mine, attachments, status, senderName);
        }

        public MessageView withoutReplyPreview() {
            return withExtras(null, reactions, myReaction);
        }
    }

    /**
     * /user/queue/message-events, type = "receipt": `kind` delivered | read; `userId` ack/okuyan kullanici,
     * `upToMessageId` alicinin bu kimlige kadar olan KENDI mesajlari `status`e (DELIVERED | READ) ilerledi.
     * Grupta toplulastirma sunucuda yapilir: yalniz tum diger aktif uyeler esigi gectiginde dusulur.
     */
    public record ReceiptEvent(String type, Long conversationId, String kind, Long upToMessageId, Long userId,
                               String at, String status) {}

    /** Tepki sonucu / olayi: toplam sayaclar ve (yalniz istek sahibi icin) kendi tepkisi. */
    public record ReactionSummary(Long messageId, List<ReactionCount> reactions, String myReaction) {}

    /** /user/queue/message-events: type = edited | deleted | reaction (okundu bilgisi /user/queue/read-receipts). */
    public record MessageEvent(String type, Long conversationId, Long messageId, Long userId, MessageView message,
                               String emoji, List<ReactionCount> reactions, String at) {}

    /**
     * /user/queue/message-events, type = "viewed": alici tek gosterimlik eki acti (gondericiye gider).
     * `message` opsiyoneldir (su an null).
     */
    public record ViewedEvent(String type, Long conversationId, Long messageId, Long attachmentId, Long userId,
                              String at, MessageView message) {}

    /** /user/queue/message-events, type = "conversation-updated": grup adi/fotografi degisti (tum uyelere). */
    public record ConversationUpdatedEvent(String type, Long conversationId, Long userId, String title,
                                           String avatarUrl, String at) {}

    /**
     * /user/queue/message-events, type = "conversation-removed": kullanici kulup/etkinlik sohbetinden dustu
     * (ayrildi, cikarildi, yasaklandi, oda kapandi/kulup silindi). Istemci konusmayi listeden ve acik ekrandan kaldirir.
     */
    public record ConversationRemovedEvent(String type, Long conversationId, String at) {}

    public record UnreadItem(Long conversationId, long unread, boolean muted) {}

    /** `total`: sessize alinmamis konusmalardaki toplam okunmamis (rozet sayisi); `mutedTotal`: sessizdekiler. */
    public record UnreadSummary(long total, long mutedTotal, List<UnreadItem> conversations) {}

    public record ConversationView(Long id, String type, String title, UserSummary peer, int memberCount,
                                   boolean admin, MessageView lastMessage, long unreadCount, boolean blocked,
                                   String createdAt, boolean muted, String mutedUntil, boolean archived,
                                   boolean mutedForever, Long communityId, Long eventId, String avatarUrl) {}

    /** `department`/`classYear`: profil gizlilik ayari bakana izin veriyorsa (yoksa gonderilmez). */
    public record MemberView(Long userId, String displayName, String avatarUrl, String role,
                             @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) String department,
                             @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL) Short classYear) {
        public MemberView(Long userId, String displayName, String avatarUrl, String role) {
            this(userId, displayName, avatarUrl, role, null, null);
        }
    }

    public record ConversationDetail(ConversationView conversation, List<MemberView> members) {}

    public record PresenceView(boolean online, String lastSeenAt) {}

    // --- WebSocket ---

    public record ChatSend(Long conversationId, String text, String clientId, Long replyToMessageId,
                           List<Long> attachmentIds, Boolean viewOnce) {
        public ChatSend(Long conversationId, String text, String clientId, Long replyToMessageId,
                        List<Long> attachmentIds) {
            this(conversationId, text, clientId, replyToMessageId, attachmentIds, null);
        }

        public ChatSend(Long conversationId, String text, String clientId, Long replyToMessageId) {
            this(conversationId, text, clientId, replyToMessageId, null, null);
        }
    }

    public record ChatRead(Long conversationId, Long lastMessageId) {}

    public record ChatDelivered(Long conversationId, Long lastMessageId) {}

    public record ChatTyping(Long conversationId) {}

    /** /user/queue/read-receipts: `userId` konusmada `lastMessageId`'ye kadar okudu. */
    public record ReadReceipt(Long conversationId, Long userId, Long lastMessageId) {}

    /** /user/queue/typing */
    public record TypingEvent(Long conversationId, Long userId) {}

    /** /user/queue/errors */
    public record ErrorFrame(String code, String message, String clientId) {}
}
