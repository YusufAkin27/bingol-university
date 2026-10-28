package edu.bingol.backend.admin.chat.action;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import java.util.List;

/** Yonetici sohbet mudahalesi (P08) istek/yanit sozlesmeleri. Ayrinti: docs/ADMIN_API.md "Sohbet mudahalesi (P08)". */
public final class ChatActionDtos {

    private ChatActionDtos() {}

    /** Sebep ya `X-Admin-Reason` basliginda ya da govdede `reason` alaninda verilir. */
    public record ReasonBody(@Size(max = 300) String reason) {}

    public record BulkHideRequest(@NotEmpty List<Long> ids, @Size(max = 300) String reason) {}

    /** state: HIDDEN | VISIBLE | PURGED; irreversible: kalici silme (geri alinamaz). */
    public record MessageActionResult(long id, long conversationId, String state, boolean irreversible) {}

    public record BulkItem(long id, boolean ok, int status, String error) {}

    public record BulkResult(int requested, int done, int failed, List<BulkItem> items) {}

    /** closed: islem sonrasi durum; notified: bildirim gonderilmeye calisilan uye sayisi. */
    public record ConversationStateResult(long id, boolean closed, String closedAt, int notified) {}

    public record MemberRemoval(long conversationId, long userId, boolean removed) {}

    /** email maskelidir (a***@bingol.edu.tr). */
    public record MemberMeta(long userId, String displayName, String email, String role, String joinedAt, String leftAt,
                             boolean active) {}

    /**
     * Sohbet ust verisi (ICERIK YOK). kind: DIRECT | GROUP | CLUB | EVENT. membersManaged: uyelik kaynaga (kulup/etkinlik)
     * bagli oldugu icin buradan cikarilamaz. members en cok {@value AdminConversationActionService#MAX_MEMBERS_LISTED} kayit.
     */
    public record ConversationMeta(long id, String type, String kind, Long communityId, Long eventId, String title,
                                   boolean closed, String closedAt, Long closedBy, String closedReason,
                                   long messageCount, int activeMemberCount, int openReportCount, String createdAt,
                                   String lastMessageAt, boolean membersManaged, boolean membersTruncated,
                                   List<MemberMeta> members) {}

    /** Disa aktarilan tek mesaj; status: VISIBLE | HIDDEN | ADMIN_HIDDEN | DELETED | PURGED. */
    public record ExportMessage(long id, String createdAt, long senderId, String senderName, String senderEmail,
                                String text, String decryptError, String status, String editedAt, Long replyToMessageId,
                                String deletedAt) {}

    /** truncated true ise `nextAfterId` ile devam edilir (en cok 5000 mesaj/istek). */
    public record ConversationExport(long conversationId, String type, String title, String exportedAt, long exportedBy,
                                     String reason, int messageCount, boolean truncated, Long nextAfterId,
                                     List<ExportMessage> messages) {}

    /** CSV disa aktarma: govde + devam bilgisi (basliklara yazilir). */
    public record CsvExport(String body, int messageCount, boolean truncated, Long nextAfterId) {}
}
