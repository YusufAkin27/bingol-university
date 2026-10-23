package edu.bingol.backend.support.ticket;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

public final class TicketDtos {

    private TicketDtos() {}

    public record CreateTicketRequest(@NotNull SupportTicket.Category category,
                                      @NotBlank @Size(max = 120) String subject,
                                      @NotBlank @Size(max = 2000) String message) {}

    public record ReplyRequest(@NotBlank @Size(max = 2000) String text) {}

    public record TicketSummary(Long id, SupportTicket.Category category, String subject, SupportTicket.Status status,
                                String createdAt, String updatedAt) {
        public static TicketSummary of(SupportTicket t) {
            return new TicketSummary(t.getId(), t.getCategory(), t.getSubject(), t.getStatus(),
                    t.getCreatedAt().toString(), t.getUpdatedAt().toString());
        }
    }

    public record TicketMessageView(Long id, boolean fromStaff, String text, String createdAt) {
        public static TicketMessageView of(SupportMessage m) {
            return new TicketMessageView(m.getId(), m.isFromStaff(), m.getText(), m.getCreatedAt().toString());
        }
    }

    public record TicketDetail(TicketSummary ticket, List<TicketMessageView> messages) {}

    public record TicketList(List<TicketSummary> items, Long nextCursor) {}

    /** Yonetici gorunumu: talep sahibi bilgisiyle. */
    public record AdminTicketSummary(Long id, Long userId, String userEmail, SupportTicket.Category category,
                                     String subject, SupportTicket.Status status, String createdAt, String updatedAt) {}

    public record AdminTicketList(List<AdminTicketSummary> items, Long nextCursor) {}
}
