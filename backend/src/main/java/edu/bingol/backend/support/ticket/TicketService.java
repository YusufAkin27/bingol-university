package edu.bingol.backend.support.ticket;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.support.ticket.TicketDtos.AdminTicketDetail;
import edu.bingol.backend.support.ticket.TicketDtos.AdminTicketList;
import edu.bingol.backend.support.ticket.TicketDtos.AdminTicketSummary;
import edu.bingol.backend.support.ticket.TicketDtos.CreateTicketRequest;
import edu.bingol.backend.support.ticket.TicketDtos.TicketDetail;
import edu.bingol.backend.support.ticket.TicketDtos.TicketList;
import edu.bingol.backend.support.ticket.TicketDtos.TicketMessageView;
import edu.bingol.backend.support.ticket.TicketDtos.TicketSummary;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TicketService {

    /** Ayni anda acik (kapatilmamis) talep ust siniri. */
    static final int MAX_OPEN_TICKETS = 5;

    private final TicketRepository tickets;
    private final SupportMessageRepository messages;
    private final UserRepository users;
    private final NotificationService notifications;

    public TicketService(TicketRepository tickets, SupportMessageRepository messages, UserRepository users,
                         NotificationService notifications) {
        this.tickets = tickets;
        this.messages = messages;
        this.users = users;
        this.notifications = notifications;
    }

    @Transactional
    public TicketDetail create(Long userId, CreateTicketRequest r) {
        if (tickets.countByUserIdAndStatusNot(userId, SupportTicket.Status.CLOSED) >= MAX_OPEN_TICKETS) {
            throw new ApiException(HttpStatus.CONFLICT, "TOO_MANY_OPEN_TICKETS",
                    "En fazla " + MAX_OPEN_TICKETS + " açık talebiniz olabilir. Önce mevcut taleplerden birini kapatın.",
                    String.valueOf(MAX_OPEN_TICKETS));
        }
        SupportTicket t = new SupportTicket();
        t.setUserId(userId);
        t.setCategory(r.category());
        t.setSubject(r.subject().trim());
        t = tickets.save(t);
        SupportMessage m = addMessage(t, userId, false, r.message());
        return new TicketDetail(TicketSummary.of(t), List.of(TicketMessageView.of(m)));
    }

    public TicketList mine(Long userId, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        CursorPage<TicketSummary> page = CursorPage.of(tickets.mine(userId, cursor, PageRequest.of(0, s + 1)), s,
                SupportTicket::getId, TicketSummary::of);
        return new TicketList(page.items(), page.nextCursor());
    }

    /** Talebi yalnizca sahibi gorur (yonetici icin adminDetail). */
    public TicketDetail detail(Long userId, Long ticketId) {
        return toDetail(ownTicket(userId, ticketId));
    }

    @Transactional
    public TicketDetail userReply(Long userId, Long ticketId, String text) {
        SupportTicket t = ownTicket(userId, ticketId);
        if (t.getStatus() == SupportTicket.Status.CLOSED) {
            throw new ApiException(HttpStatus.CONFLICT, "TICKET_CLOSED", "Bu talep kapatılmış. Yeni bir talep açın.");
        }
        addMessage(t, userId, false, text);
        t.setStatus(SupportTicket.Status.OPEN);
        t.setUpdatedAt(Instant.now());
        return toDetail(tickets.save(t));
    }

    @Transactional
    public void userClose(Long userId, Long ticketId) {
        close(ownTicket(userId, ticketId));
    }

    // --- yonetici ---

    public AdminTicketList adminQueue(SupportTicket.Status status, boolean publicOnly, Long cursor, int size) {
        int s = CursorPage.clampSize(size);
        List<SupportTicket> rows = tickets.queue(status, publicOnly, cursor, PageRequest.of(0, s + 1));
        List<SupportTicket> pageRows = rows.size() > s ? rows.subList(0, s) : rows;
        Map<Long, User> byId = users.findAllById(pageRows.stream().map(SupportTicket::getUserId).filter(java.util.Objects::nonNull).distinct().toList())
                .stream().collect(Collectors.toMap(User::getId, Function.identity()));
        CursorPage<AdminTicketSummary> page = CursorPage.of(rows, s, SupportTicket::getId, t -> new AdminTicketSummary(
                t.getId(), t.getUserId(),
                t.isPublicTicket() ? t.getContactEmail()
                        : (byId.containsKey(t.getUserId()) ? byId.get(t.getUserId()).getEmail() : null),
                t.getCategory(), t.getSubject(), t.getStatus(), t.getCreatedAt().toString(), t.getUpdatedAt().toString(),
                t.isPublicTicket(), t.getPriority(), t.getAssigneeId()));
        return new AdminTicketList(page.items(), page.nextCursor());
    }

    public AdminTicketDetail adminDetail(Long ticketId) {
        SupportTicket t = find(ticketId);
        TicketDetail d = toDetail(t);
        String email = t.isPublicTicket() ? t.getContactEmail()
                : users.findById(t.getUserId()).map(User::getEmail).orElse(null);
        return new AdminTicketDetail(d.ticket(), d.messages(), t.getUserId(), email);
    }

    @Transactional
    public TicketDetail staffReply(Long staffId, Long ticketId, String text) {
        SupportTicket t = find(ticketId);
        if (t.getStatus() == SupportTicket.Status.CLOSED) {
            throw new ApiException(HttpStatus.CONFLICT, "TICKET_CLOSED", "Talep kapalı.");
        }
        addMessage(t, staffId, true, text);
        t.setStatus(SupportTicket.Status.ANSWERED);
        t.setUpdatedAt(Instant.now());
        tickets.save(t);
        if (t.getUserId() != null) {
            notifications.sendLocalized(t.getUserId(), NotificationType.SYSTEM, "notif.ticket.answered.title", null,
                    t.getSubject(), Map.of("ticketId", String.valueOf(t.getId())));
        }
        return toDetail(t);
    }

    @Transactional
    public void staffClose(Long ticketId) {
        SupportTicket t = find(ticketId);
        close(t);
        if (t.getUserId() != null) {
            notifications.sendLocalized(t.getUserId(), NotificationType.SYSTEM, "notif.ticket.closed.title", null,
                    t.getSubject(), Map.of("ticketId", String.valueOf(t.getId())));
        }
    }

    // --- yardimcilar ---

    private void close(SupportTicket t) {
        if (t.getStatus() != SupportTicket.Status.CLOSED) {
            t.setStatus(SupportTicket.Status.CLOSED);
            t.setClosedAt(Instant.now());
            t.setUpdatedAt(Instant.now());
            tickets.save(t);
        }
    }

    private SupportMessage addMessage(SupportTicket t, Long authorId, boolean fromStaff, String text) {
        SupportMessage m = new SupportMessage();
        m.setTicketId(t.getId());
        m.setAuthorId(authorId);
        m.setFromStaff(fromStaff);
        m.setText(text.trim());
        return messages.save(m);
    }

    private TicketDetail toDetail(SupportTicket t) {
        return new TicketDetail(TicketSummary.of(t),
                messages.findByTicketIdOrderByIdAsc(t.getId()).stream().map(TicketMessageView::of).toList());
    }

    private SupportTicket find(Long id) {
        return tickets.findById(id)
                .filter(t -> t.isEmailVerified()) // dogrulanmamis herkese acik talep yok sayilir
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "TICKET_NOT_FOUND", "Talep bulunamadı."));
    }

    /** Baskasinin talebi icin de 404 doner (varligini sizdirmaz). */
    private SupportTicket ownTicket(Long userId, Long id) {
        SupportTicket t = find(id);
        if (!t.getUserId().equals(userId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "TICKET_NOT_FOUND", "Talep bulunamadı.");
        }
        return t;
    }
}
