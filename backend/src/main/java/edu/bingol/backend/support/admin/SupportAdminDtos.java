package edu.bingol.backend.support.admin;

import edu.bingol.backend.support.ticket.SupportTicket;
import edu.bingol.backend.support.ticket.TicketDtos.TicketSummary;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

/** Yonetici destek tamamlama (P12) istek/yanit tipleri. Bu tipler YALNIZ /api/admin uclarindan doner. */
public final class SupportAdminDtos {

    private SupportAdminDtos() {}

    /**
     * Yonetici mesaj satiri: internal=true IC NOT'tur (musteriye gorunmez). id'ler mesaj ve not tablolarinda ayri
     * sayilir; istemci anahtari internal + id ile kurmalidir.
     */
    public record AdminMessageView(Long id, boolean fromStaff, boolean internal, String text, String createdAt,
                                   Long authorId) {}

    /** Yonetici talep ayrintisi: mesajlar + ic notlar, oncelik ve atama. */
    public record AdminTicketDetailView(TicketSummary ticket, List<AdminMessageView> messages, Long userId,
                                        String userEmail, SupportTicket.Priority priority, Long assigneeId,
                                        String assigneeName) {}

    /** Verilmeyen (null) alan degismez; atamayi kaldirmak icin unassign=true. */
    public record TicketPatch(SupportTicket.Priority priority, Long assigneeId, Boolean unassign,
                              SupportTicket.Category category) {}

    public record NoteRequest(@NotBlank @Size(max = 2000) String text) {}

    public record ReasonRequest(@NotBlank @Size(min = 5, max = 300) String reason) {}

    public record MergeRequest(@NotNull Long sourceId, @NotNull Long targetId,
                               @NotBlank @Size(min = 5, max = 300) String reason) {}

    public record MergeResult(Long sourceId, Long targetId, int voteCount) {}

    public record FaqOrderRequest(@NotEmpty @Size(max = 200) List<Long> ids) {}
}
