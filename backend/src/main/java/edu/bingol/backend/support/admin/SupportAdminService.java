package edu.bingol.backend.support.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.support.admin.SupportAdminDtos.AdminMessageView;
import edu.bingol.backend.support.admin.SupportAdminDtos.AdminTicketDetailView;
import edu.bingol.backend.support.admin.SupportAdminDtos.TicketPatch;
import edu.bingol.backend.support.ticket.SupportMessage;
import edu.bingol.backend.support.ticket.SupportMessageRepository;
import edu.bingol.backend.support.ticket.SupportTicket;
import edu.bingol.backend.support.ticket.SupportTrackTokenRepository;
import edu.bingol.backend.support.ticket.TicketDtos.TicketSummary;
import edu.bingol.backend.support.ticket.TicketRepository;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Yonetici destek tamamlama (P12): ic not, yeniden acma, oncelik/atama, silme. Ic notlar musteriye GORUNMEZ:
 * yalniz {@link #detail} (yonetici ucu) notlari mesajlarla birlestirir; kullanici/herkese acik uclar TicketService ve
 * PublicSupportService uzerinden yalniz support_message okur.
 */
@Service
public class SupportAdminService {

    private final TicketRepository tickets;
    private final SupportMessageRepository messages;
    private final SupportTicketNoteRepository notes;
    private final SupportTrackTokenRepository trackTokens;
    private final UserRepository users;
    private final NotificationService notifications;

    public SupportAdminService(TicketRepository tickets, SupportMessageRepository messages,
                               SupportTicketNoteRepository notes, SupportTrackTokenRepository trackTokens,
                               UserRepository users, NotificationService notifications) {
        this.tickets = tickets;
        this.messages = messages;
        this.notes = notes;
        this.trackTokens = trackTokens;
        this.users = users;
        this.notifications = notifications;
    }

    @Transactional(readOnly = true)
    public AdminTicketDetailView detail(Long ticketId) {
        SupportTicket t = find(ticketId);
        List<Row> all = new ArrayList<>();
        for (SupportMessage m : messages.findByTicketIdOrderByIdAsc(t.getId())) {
            all.add(new Row(m.getCreatedAt(), new AdminMessageView(m.getId(), m.isFromStaff(), false, m.getText(),
                    m.getCreatedAt().toString(), m.getAuthorId())));
        }
        for (SupportTicketNote n : notes.findByTicketIdOrderByIdAsc(t.getId())) {
            all.add(new Row(n.getCreatedAt(), new AdminMessageView(n.getId(), true, true, n.getText(),
                    n.getCreatedAt().toString(), n.getAuthorId())));
        }
        // zaman sirasi; esitlikte once mesaj sonra not
        all.sort(Comparator.comparing(Row::at).thenComparing(r -> r.view().internal()).thenComparing(r -> r.view().id()));
        // T-018: users.pii olmayan profil maskeli gorur; yanit e-postasini sunucu gonderir (istemci adresi bilmez)
        String email = PermissionAwareMasking.email(t.isPublicTicket() ? t.getContactEmail()
                : t.getUserId() == null ? null : users.findById(t.getUserId()).map(User::getEmail).orElse(null));
        String assignee = t.getAssigneeId() == null ? null
                : users.findById(t.getAssigneeId()).map(User::getDisplayName).orElse(null);
        return new AdminTicketDetailView(TicketSummary.of(t), all.stream().map(Row::view).toList(), t.getUserId(), email, t.getPriority(),
                t.getAssigneeId(), assignee);
    }

    /** Kapali talebi yeniden acar (OPEN). Kullanicisi varsa bildirim gider. */
    @Transactional
    public AdminTicketDetailView reopen(Long ticketId) {
        SupportTicket t = find(ticketId);
        if (t.getStatus() != SupportTicket.Status.CLOSED) {
            throw new ApiException(HttpStatus.CONFLICT, "TICKET_NOT_CLOSED", "Talep zaten açık.");
        }
        t.setStatus(SupportTicket.Status.OPEN);
        t.setClosedAt(null);
        t.setUpdatedAt(Instant.now());
        tickets.save(t);
        AuditContext.target("TICKET", ticketId).summary("yeniden açıldı");
        if (t.getUserId() != null) {
            notifications.sendLocalized(t.getUserId(), NotificationType.SYSTEM, "notif.ticket.reopened.title", null,
                    t.getSubject(), Map.of("ticketId", String.valueOf(t.getId())));
        }
        return detail(ticketId);
    }

    @Transactional
    public AdminTicketDetailView update(Long ticketId, TicketPatch p) {
        SupportTicket t = find(ticketId);
        boolean unassign = Boolean.TRUE.equals(p.unassign());
        if (p.priority() == null && p.assigneeId() == null && !unassign && p.category() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TICKET_PATCH_EMPTY", "Değiştirilecek alan verilmedi.");
        }
        if (unassign && p.assigneeId() != null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "TICKET_PATCH_EMPTY", "Atama hem verilip hem kaldırılamaz.");
        }
        List<String> changes = new ArrayList<>();
        if (p.priority() != null && p.priority() != t.getPriority()) {
            changes.add("öncelik " + t.getPriority() + "->" + p.priority());
            t.setPriority(p.priority());
        }
        if (p.category() != null && p.category() != t.getCategory()) {
            changes.add("kategori " + t.getCategory() + "->" + p.category());
            t.setCategory(p.category());
        }
        if (unassign && t.getAssigneeId() != null) {
            changes.add("atama kaldırıldı");
            t.setAssigneeId(null);
        } else if (p.assigneeId() != null && !p.assigneeId().equals(t.getAssigneeId())) {
            User a = users.findById(p.assigneeId()).orElseThrow(() ->
                    new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Kullanıcı bulunamadı."));
            if (a.getRole() != Role.ADMIN || a.getStatus() != UserStatus.ACTIVE) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "ASSIGNEE_NOT_ADMIN",
                        "Talep yalnızca etkin bir yöneticiye atanabilir.");
            }
            changes.add("atanan " + a.getId());
            t.setAssigneeId(a.getId());
        }
        if (!changes.isEmpty()) {
            t.setUpdatedAt(Instant.now());
            tickets.save(t);
        }
        AuditContext.target("TICKET", ticketId).summary(changes.isEmpty() ? "değişiklik yok" : String.join("; ", changes));
        return detail(ticketId);
    }

    /** Ic not ekler; musteriye bildirim/e-posta GITMEZ. */
    @Transactional
    public AdminMessageView addNote(Long ticketId, Long adminId, String text) {
        SupportTicket t = find(ticketId);
        SupportTicketNote n = new SupportTicketNote();
        n.setTicketId(t.getId());
        n.setAuthorId(adminId);
        n.setText(text.trim());
        n = notes.save(n);
        AuditContext.target("TICKET", ticketId).summary("iç not eklendi");
        return new AdminMessageView(n.getId(), true, true, n.getText(), n.getCreatedAt().toString(), n.getAuthorId());
    }

    /** Geri alinamaz: mesajlar, ic notlar, durum baglantilari (herkese acik talep) ve talep silinir. */
    @Transactional
    public void delete(Long ticketId, String reason) {
        SupportTicket t = find(ticketId);
        trackTokens.deleteByTicketId(t.getId());
        notes.deleteByTicketId(t.getId());
        messages.deleteByTicketId(t.getId());
        tickets.delete(t);
        AuditContext.target("TICKET", ticketId).reason(reason)
                .summary("silindi; herkese açık=" + t.isPublicTicket() + "; kategori=" + t.getCategory());
    }

    private record Row(Instant at, AdminMessageView view) {}

    /** Dogrulanmamis herkese acik talep yok sayilir (yonetici listesinde de gorunmez). */
    private SupportTicket find(Long id) {
        return tickets.findById(id).filter(SupportTicket::isEmailVerified).orElseThrow(() ->
                new ApiException(HttpStatus.NOT_FOUND, "TICKET_NOT_FOUND", "Talep bulunamadı."));
    }
}
