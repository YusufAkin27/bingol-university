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
    public record SendMessageRequest(String text, @NotBlank @Size(max = 64) String clientId,
                                     @Size(max = 4) List<Long> attachmentIds) {
        public SendMessageRequest(String text, String clientId) {
            this(text, clientId, null);
        }
    }

    public record ReadRequest(@NotNull Long lastMessageId) {}

    public record ReportMessageRequest(@NotNull ReportReason reason, @Size(max = 500) String note) {}

    // --- yanitlar ---

    public record UserSummary(Long id, String displayName, String avatarUrl) {
        public static UserSummary of(User u) {
            return new UserSummary(u.getId(), u.getDisplayName(), u.getAvatarUrl());
        }
    }

    /** Gizlenen / engelli kullanicidan gelen mesajlarda `text` sabit bir aciklamadir, `removed` true olur. */
    public record MessageView(Long id, Long conversationId, Long senderId, String clientId, String text,
                              boolean removed, String createdAt, List<AttachmentView> attachments) {
        public MessageView(Long id, Long conversationId, Long senderId, String clientId, String text,
                           boolean removed, String createdAt) {
            this(id, conversationId, senderId, clientId, text, removed, createdAt, List.of());
        }

        /** T8: gorsel ekleri ekler (gizlenen/engelli mesajda ek gosterilmez). */
        public MessageView withAttachments(List<AttachmentView> list) {
            return removed || list == null ? this : new MessageView(id, conversationId, senderId, clientId, text,
                    removed, createdAt, List.copyOf(list));
        }

        public static MessageView of(Message m) {
            return of(m, false);
        }

        public static MessageView of(Message m, boolean senderBlocked) {
            // Cozulemeyen (anahtar/etiket hatasi) mesaj tum listeyi bozmasin: sabit metinle gosterilir.
            boolean unreadable = !m.isHidden() && !senderBlocked && m.getBody() == null;
            boolean removed = m.isHidden() || senderBlocked || unreadable;
            String text = m.isHidden() ? REMOVED_TEXT : senderBlocked ? BLOCKED_TEXT
                    : unreadable ? UNREADABLE_TEXT : m.getBody();
            return new MessageView(m.getId(), m.getConversationId(), m.getSenderId(), m.getClientId(), text,
                    removed, m.getCreatedAt().toString());
        }
    }

    public record ConversationView(Long id, String type, String title, UserSummary peer, int memberCount,
                                   boolean admin, MessageView lastMessage, long unreadCount, boolean blocked,
                                   String createdAt) {}

    public record MemberView(Long userId, String displayName, String avatarUrl, String role) {}

    public record ConversationDetail(ConversationView conversation, List<MemberView> members) {}

    public record PresenceView(boolean online, String lastSeenAt) {}

    // --- WebSocket ---

    public record ChatSend(Long conversationId, String text, String clientId, List<Long> attachmentIds) {
        public ChatSend(Long conversationId, String text, String clientId) {
            this(conversationId, text, clientId, null);
        }
    }

    public record ChatRead(Long conversationId, Long lastMessageId) {}

    public record ChatTyping(Long conversationId) {}

    /** /user/queue/read-receipts: `userId` konusmada `lastMessageId`'ye kadar okudu. */
    public record ReadReceipt(Long conversationId, Long userId, Long lastMessageId) {}

    /** /user/queue/typing */
    public record TypingEvent(Long conversationId, Long userId) {}

    /** /user/queue/errors */
    public record ErrorFrame(String code, String message, String clientId) {}
}
