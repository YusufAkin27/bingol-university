package edu.bingol.backend.support.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.rbac.PermissionAwareMasking;
import edu.bingol.backend.admin.Csv;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.support.feedback.Feedback;
import edu.bingol.backend.support.feedback.FeedbackRepository;
import edu.bingol.backend.support.ticket.SupportTicket;
import edu.bingol.backend.support.ticket.TicketRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import jakarta.persistence.criteria.Predicate;
import jakarta.servlet.http.HttpServletResponse;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Destek talepleri ve geri bildirimler CSV dokumu (P12): suzgecli, en cok {@value #MAX_ROWS} satir, UTF-8 BOM, formul
 * kacisli. Ic notlar ve mesaj govdeleri DISA AKTARILMAZ (yalniz ust bilgi); istekler denetim kaydina yazilir.
 */
@RestController
@RequestMapping("/api/admin/support")
public class SupportExportController {

    static final int MAX_ROWS = 50_000;
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final List<String> TICKET_HEADER = Arrays.asList("id", "durum", "kategori", "oncelik", "atananId",
            "konu", "kullaniciId", "eposta", "herkeseAcik", "olusturma", "guncelleme", "kapanis");
    private static final List<String> FEEDBACK_HEADER = Arrays.asList("id", "kategori", "durum", "konu", "kullaniciId",
            "eposta", "herkeseAcik", "oy", "platform", "surum", "olusturma", "yanitTarihi");

    private final TicketRepository tickets;
    private final FeedbackRepository feedback;
    private final UserRepository users;
    private final RateLimiter limiter;

    public SupportExportController(TicketRepository tickets, FeedbackRepository feedback, UserRepository users,
                                   RateLimiter limiter) {
        this.tickets = tickets;
        this.feedback = feedback;
        this.users = users;
        this.limiter = limiter;
    }

    @GetMapping("/tickets/export.csv")
    public void ticketsCsv(@RequestParam(required = false) SupportTicket.Status status,
                           @RequestParam(required = false) SupportTicket.Category category,
                           @RequestParam(required = false) SupportTicket.Priority priority,
                           @RequestParam(required = false) Long assigneeId,
                           @RequestParam(defaultValue = "false") boolean publicOnly,
                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                           HttpServletResponse res) throws IOException {
        limit();
        Instant f = from == null ? null : from.atStartOfDay(ZONE).toInstant();
        Instant t = to == null ? null : to.plusDays(1).atStartOfDay(ZONE).toInstant();
        Specification<SupportTicket> spec = (root, q, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            ps.add(cb.isTrue(root.get("emailVerified"))); // dogrulanmamis herkese acik talepler hic gorunmez
            if (status != null) {
                ps.add(cb.equal(root.get("status"), status));
            }
            if (category != null) {
                ps.add(cb.equal(root.get("category"), category));
            }
            if (priority != null) {
                ps.add(cb.equal(root.get("priority"), priority));
            }
            if (assigneeId != null) {
                ps.add(cb.equal(root.get("assigneeId"), assigneeId));
            }
            if (publicOnly) {
                ps.add(cb.isTrue(root.get("publicTicket")));
            }
            if (f != null) {
                ps.add(cb.greaterThanOrEqualTo(root.<Instant>get("createdAt"), f));
            }
            if (t != null) {
                ps.add(cb.lessThan(root.<Instant>get("createdAt"), t));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };
        List<SupportTicket> rows = tickets.findAll(spec, PageRequest.of(0, MAX_ROWS, Sort.by(Sort.Direction.DESC, "id")))
                .getContent();
        Map<Long, String> emails = emailsOf(rows.stream().map(SupportTicket::getUserId).toList());
        try {
            write(res, "talepler.csv", TICKET_HEADER, rows.stream().map(r -> Arrays.<Object>asList(r.getId(),
                    r.getStatus(), r.getCategory(), r.getPriority(), r.getAssigneeId(), r.getSubject(), r.getUserId(),
                    PermissionAwareMasking.email(r.isPublicTicket() ? r.getContactEmail() : emails.get(r.getUserId())),
                    r.isPublicTicket(),
                    r.getCreatedAt(), r.getUpdatedAt(), r.getClosedAt())).toList());
        } finally {
            AuditContext.target("TICKET", null).summary("csv satir=" + rows.size());
        }
    }

    @GetMapping("/feedback/export.csv")
    public void feedbackCsv(@RequestParam(required = false) Feedback.Status status,
                            @RequestParam(required = false) Feedback.Category category,
                            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                            HttpServletResponse res) throws IOException {
        limit();
        Instant f = from == null ? null : from.atStartOfDay(ZONE).toInstant();
        Instant t = to == null ? null : to.plusDays(1).atStartOfDay(ZONE).toInstant();
        Specification<Feedback> spec = (root, q, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if (status != null) {
                ps.add(cb.equal(root.get("status"), status));
            }
            if (category != null) {
                ps.add(cb.equal(root.get("category"), category));
            }
            if (f != null) {
                ps.add(cb.greaterThanOrEqualTo(root.<Instant>get("createdAt"), f));
            }
            if (t != null) {
                ps.add(cb.lessThan(root.<Instant>get("createdAt"), t));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };
        List<Feedback> rows = feedback.findAll(spec, PageRequest.of(0, MAX_ROWS, Sort.by(Sort.Direction.DESC, "id")))
                .getContent();
        Map<Long, String> emails = emailsOf(rows.stream().map(Feedback::getUserId).toList());
        try {
            write(res, "geri-bildirimler.csv", FEEDBACK_HEADER, rows.stream().map(r -> Arrays.<Object>asList(r.getId(),
                    r.getCategory(), r.getStatus(), r.getSubject(), r.getUserId(),
                    PermissionAwareMasking.email(emails.get(r.getUserId())),
                    r.isPublicVisible(), r.getVoteCount(), r.getPlatform(), r.getAppVersion(), r.getCreatedAt(),
                    r.getRespondedAt())).toList());
        } finally {
            AuditContext.target("FEEDBACK", null).summary("csv satir=" + rows.size());
        }
    }

    private Map<Long, String> emailsOf(List<Long> userIds) {
        Set<Long> ids = userIds.stream().filter(java.util.Objects::nonNull).collect(Collectors.toSet());
        Map<Long, String> out = new HashMap<>();
        if (!ids.isEmpty()) {
            for (User u : users.findAllById(ids)) {
                out.put(u.getId(), u.getEmail());
            }
        }
        return out;
    }

    static void write(HttpServletResponse res, String filename, List<String> header, List<List<Object>> rows)
            throws IOException {
        res.setStatus(HttpStatus.OK.value());
        res.setContentType("text/csv; charset=UTF-8");
        res.setHeader(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"");
        res.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        try (Writer w = new BufferedWriter(new OutputStreamWriter(res.getOutputStream(), StandardCharsets.UTF_8))) {
            w.write(Csv.BOM);
            w.write(Csv.row(header));
            for (List<Object> r : rows) {
                w.write(Csv.row(r));
            }
            w.flush();
        }
    }

    private void limit() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        String actor = a != null && a.getPrincipal() instanceof Long id ? String.valueOf(id) : "basic";
        limiter.check("admcsv:" + actor, 10, Duration.ofMinutes(1));
    }
}
