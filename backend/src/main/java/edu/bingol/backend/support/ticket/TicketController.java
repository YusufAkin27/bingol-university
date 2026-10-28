package edu.bingol.backend.support.ticket;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.support.ticket.TicketDtos.AdminTicketList;
import edu.bingol.backend.support.ticket.TicketDtos.CreateTicketRequest;
import edu.bingol.backend.support.ticket.TicketDtos.ReplyRequest;
import edu.bingol.backend.support.ticket.TicketDtos.TicketDetail;
import edu.bingol.backend.support.ticket.TicketDtos.TicketList;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Destek talepleri: kullanici ile destek ekibi arasinda konusma akisi. */
@RestController
@RequestMapping("/api")
public class TicketController {

    private final TicketService tickets;
    private final RateLimiter limiter;
    private final PublicSupportService publicSupport;
    private final edu.bingol.backend.support.admin.SupportAdminService adminSupport;

    public TicketController(TicketService tickets, RateLimiter limiter, PublicSupportService publicSupport,
                            edu.bingol.backend.support.admin.SupportAdminService adminSupport) {
        this.publicSupport = publicSupport;
        this.adminSupport = adminSupport;
        this.tickets = tickets;
        this.limiter = limiter;
    }

    /** Kullanici basina gunde 5 yeni talep. */
    @PostMapping("/support/tickets")
    @ResponseStatus(HttpStatus.CREATED)
    public TicketDetail create(@Valid @RequestBody CreateTicketRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("ticket:create:" + uid, 5, Duration.ofDays(1));
        return tickets.create(uid, r);
    }

    @GetMapping("/support/tickets")
    public TicketList mine(@RequestParam(required = false) Long cursor, @RequestParam(defaultValue = "20") int size) {
        return tickets.mine(CurrentUser.id(), cursor, size);
    }

    @GetMapping("/support/tickets/{id}")
    public TicketDetail detail(@PathVariable Long id) {
        return tickets.detail(CurrentUser.id(), id);
    }

    @PostMapping("/support/tickets/{id}/messages")
    public TicketDetail reply(@PathVariable Long id, @Valid @RequestBody ReplyRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("ticket:reply:" + uid, 30, Duration.ofHours(1));
        return tickets.userReply(uid, id, r.text());
    }

    @PostMapping("/support/tickets/{id}/close")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void close(@PathVariable Long id) {
        tickets.userClose(CurrentUser.id(), id);
    }

    // --- yonetici (JWT ile giren ADMIN; yanit yazari olarak kimligi gerekir) ---

    @GetMapping("/admin/support/tickets")
    public AdminTicketList adminQueue(@RequestParam(required = false) SupportTicket.Status status,
                                      @RequestParam(defaultValue = "false") boolean publicOnly,
                                      @RequestParam(required = false) Long cursor,
                                      @RequestParam(defaultValue = "20") int size) {
        return tickets.adminQueue(status, publicOnly, cursor, size);
    }

    /**
     * Destek yazışması kişisel veri içerir: okuma denetim kaydına yazılır. Yanıt, mesajlara ek olarak İÇ NOTLARI
     * (`internal:true`, müşteriye görünmez), öncelik ve atamayı içerir (P12; yalnız yönetici ucu).
     */
    @edu.bingol.backend.admin.AuditRead
    @GetMapping("/admin/support/tickets/{id}")
    public edu.bingol.backend.support.admin.SupportAdminDtos.AdminTicketDetailView adminDetail(@PathVariable Long id) {
        return adminSupport.detail(id);
    }

    @PostMapping("/admin/support/tickets/{id}/reply")
    public TicketDtos.StaffReplyResult staffReply(@PathVariable Long id, @Valid @RequestBody ReplyRequest r) {
        TicketDetail d = tickets.staffReply(CurrentUser.id(), id, r.text());
        // Yanit kaydedildi; herkese acik talepte e-posta sonucu ayrica bildirilir (basarisizlik yaniti geri almaz)
        String mail = d.ticket().publicTicket()
                ? (publicSupport.sendStaffReplyMail(id, r.text()) ? "SENT" : "FAILED") : "NOT_APPLICABLE";
        return new TicketDtos.StaffReplyResult(d.ticket(), d.messages(), mail);
    }

    @PostMapping("/admin/support/tickets/{id}/close")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void staffClose(@PathVariable Long id) {
        tickets.staffClose(id);
    }
}
