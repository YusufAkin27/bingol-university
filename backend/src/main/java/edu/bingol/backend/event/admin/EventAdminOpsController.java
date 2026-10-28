package edu.bingol.backend.event.admin;

import edu.bingol.backend.admin.AdminReasonRequired;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.AuditRead;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminAnnouncementRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminApplicationPage;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminAttendanceView;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminCertificateRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminFeedbackPage;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AdminOrganizerRow;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.ApplicationDecision;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AttendanceMarkRequest;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.AttendanceMarkResult;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.BulkRequest;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.BulkResult;
import edu.bingol.backend.event.admin.AdminEventOpsDtos.ReasonBody;
import edu.bingol.backend.event.admission.EventAdmission;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.UncheckedIOException;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.function.ToIntFunction;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici etkinlik derin yonetimi (P07): /api/admin/events/{id}/applications|attendance|certificates|feedback|
 * announcements|organizers, CSV'ler ve toplu islem. Ayrinti: docs/ADMIN_API.md "Etkinlik derin yonetimi (P07)".
 *
 * <p>Guvenlik: /api/admin/** SecurityConfig'te ADMIN ister; yazmalar AuditInterceptor ile denetlenir (hedef EVENT/{id});
 * hiz siniri ve yikici islem siniri AdminGuardInterceptor/AdminGuardPolicy'de; sebep zorunlulugu
 * {@link AdminReasonRequired} (yazma uclarinda; okumalarda aranmaz). Sebep: X-Admin-Reason basligi ya da govdede `reason`.
 */
@RestController
@RequestMapping("/api/admin/events")
public class EventAdminOpsController {

    static final int READ_PER_MINUTE = 120;

    private final EventAdminOpsService ops;
    private final EventAdminBulkService bulk;
    private final EventAdminCsvService csv;
    private final EventAdminAuditWriter auditWriter;
    private final RateLimiter limiter;

    public EventAdminOpsController(EventAdminOpsService ops, EventAdminBulkService bulk, EventAdminCsvService csv,
                                   EventAdminAuditWriter auditWriter, RateLimiter limiter) {
        this.ops = ops;
        this.bulk = bulk;
        this.csv = csv;
        this.auditWriter = auditWriter;
        this.limiter = limiter;
    }

    // ---- basvurular ----

    /** status: PENDING|ACCEPTED|WAITLISTED|REJECTED|CANCELLED (bos = hepsi). E-posta maskeli; kapasite ozeti dahil. */
    @AuditRead
    @GetMapping("/{id}/applications")
    public AdminApplicationPage applications(@PathVariable Long id, @RequestParam(required = false) String status,
                                             @RequestParam(required = false) Long cursor,
                                             @RequestParam(defaultValue = "50") int size) {
        readLimit();
        AuditContext.target("EVENT", id);
        return ops.applications(id, status, cursor, size);
    }

    @AdminReasonRequired
    @PostMapping("/{id}/applications/{userId}/accept")
    public ApplicationDecision accept(@PathVariable Long id, @PathVariable Long userId,
                                      @Valid @RequestBody(required = false) ReasonBody body) {
        AuditContext.target("EVENT", id).reason(reason(body));
        return ops.accept(adminId(), id, userId);
    }

    @AdminReasonRequired
    @PostMapping("/{id}/applications/{userId}/reject")
    public ApplicationDecision reject(@PathVariable Long id, @PathVariable Long userId,
                                      @Valid @RequestBody(required = false) ReasonBody body) {
        AuditContext.target("EVENT", id).reason(reason(body));
        return ops.reject(adminId(), id, userId);
    }

    // ---- yoklama ----

    @AuditRead
    @GetMapping("/{id}/attendance")
    public AdminAttendanceView attendance(@PathVariable Long id) {
        readLimit();
        AuditContext.target("EVENT", id);
        return ops.attendance(id);
    }

    @AdminReasonRequired
    @PutMapping("/{id}/attendance/{userId}")
    public AttendanceMarkResult mark(@PathVariable Long id, @PathVariable Long userId,
                                     @Valid @RequestBody AttendanceMarkRequest body) {
        AuditContext.target("EVENT", id).reason(body.reason());
        return ops.mark(adminId(), id, userId, body.present());
    }

    // ---- sertifikalar ----

    @AuditRead
    @GetMapping("/{id}/certificates")
    public CursorPage<AdminCertificateRow> certificates(@PathVariable Long id, @RequestParam(required = false) Long cursor,
                                                        @RequestParam(defaultValue = "50") int size) {
        readLimit();
        AuditContext.target("EVENT", id);
        return ops.certificates(id, cursor, size);
    }

    @AdminReasonRequired
    @PostMapping("/{id}/certificates/{userId}/revoke")
    public AdminCertificateRow revoke(@PathVariable Long id, @PathVariable Long userId,
                                      @Valid @RequestBody(required = false) ReasonBody body) {
        String reason = reason(body);
        AuditContext.target("EVENT", id).reason(reason);
        return ops.revokeCertificate(adminId(), id, userId, reason);
    }

    @AdminReasonRequired
    @PostMapping("/{id}/certificates/{userId}/restore")
    public AdminCertificateRow restore(@PathVariable Long id, @PathVariable Long userId,
                                       @Valid @RequestBody(required = false) ReasonBody body) {
        AuditContext.target("EVENT", id).reason(reason(body));
        return ops.restoreCertificate(adminId(), id, userId);
    }

    // ---- geri bildirim (anonim) ----

    @GetMapping("/{id}/feedback")
    public AdminFeedbackPage feedback(@PathVariable Long id, @RequestParam(required = false) Long cursor,
                                      @RequestParam(defaultValue = "50") int size) {
        readLimit();
        return ops.feedback(id, cursor, size);
    }

    @AdminReasonRequired
    @DeleteMapping("/{id}/feedback/{fid}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteFeedback(@PathVariable Long id, @PathVariable Long fid,
                               @Valid @RequestBody(required = false) ReasonBody body) {
        AuditContext.target("EVENT", id).reason(reason(body));
        ops.deleteFeedback(id, fid);
    }

    // ---- duyurular ----

    @GetMapping("/{id}/announcements")
    public CursorPage<AdminAnnouncementRow> announcements(@PathVariable Long id, @RequestParam(required = false) Long cursor,
                                                          @RequestParam(defaultValue = "50") int size) {
        readLimit();
        return ops.announcements(id, cursor, size);
    }

    @AdminReasonRequired
    @DeleteMapping("/{id}/announcements/{aid}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAnnouncement(@PathVariable Long id, @PathVariable Long aid,
                                   @Valid @RequestBody(required = false) ReasonBody body) {
        AuditContext.target("EVENT", id).reason(reason(body));
        ops.deleteAnnouncement(id, aid);
    }

    // ---- duzenleyenler ----

    @AuditRead
    @GetMapping("/{id}/organizers")
    public List<AdminOrganizerRow> organizers(@PathVariable Long id) {
        readLimit();
        AuditContext.target("EVENT", id);
        return ops.organizers(id);
    }

    @AdminReasonRequired
    @DeleteMapping("/{id}/organizers/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeOrganizer(@PathVariable Long id, @PathVariable Long userId,
                                @Valid @RequestBody(required = false) ReasonBody body) {
        AuditContext.target("EVENT", id).reason(reason(body));
        ops.removeOrganizer(id, userId);
    }

    // ---- CSV (kisisel veri kisitli: e-posta maskeli) ----

    @AuditRead
    @GetMapping("/{id}/attendance.csv")
    public void attendanceCsv(@PathVariable Long id, HttpServletResponse res) throws IOException {
        readLimit();
        stream(res, "event-" + id + "-attendance.csv", id, w -> csv.attendance(id, w));
    }

    @AuditRead
    @GetMapping("/{id}/applications.csv")
    public void applicationsCsv(@PathVariable Long id, @RequestParam(required = false) String status,
                                HttpServletResponse res) throws IOException {
        readLimit();
        stream(res, "event-" + id + "-applications.csv", id, w -> csv.applications(id, status, w));
    }

    /** GET /api/admin/events ile ayni suzgecler; status bos = ALL. En cok 50.000 satir. */
    @AuditRead
    @GetMapping("/export.csv")
    public void eventsCsv(@RequestParam(required = false) String status, @RequestParam(required = false) String q,
                          @RequestParam(required = false) Long communityId,
                          @RequestParam(defaultValue = "false") boolean standalone,
                          @RequestParam(required = false) EventAdmission.Mode joinPolicy,
                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
                          @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
                          HttpServletResponse res) throws IOException {
        readLimit();
        stream(res, "events.csv", null, w -> csv.events(status, q, communityId, standalone, joinPolicy, from, to, w));
    }

    // ---- toplu islem ----

    /**
     * Toplu gizle / yeniden yayinla / iptal (en cok 100 etkinlik). Sebep zorunlu (AdminGuardPolicy: .../bulk). Her
     * etkinlik ayri islenir; kismi basari 200 ile raporlanir, her etkinlik icin ayri denetim satiri yazilir.
     */
    @PostMapping("/bulk")
    public BulkResult bulk(@Valid @RequestBody BulkRequest r, HttpServletRequest req) {
        String reason = r.reason() != null && !r.reason().isBlank() ? r.reason() : AuditContext.currentReason();
        AuditContext.target("EVENT", null).reason(reason);
        BulkResult res = bulk.run(adminId(), r.action(), r.ids(), reason);
        AuditContext.summary("toplu " + r.action() + ": " + res.done() + "/" + res.requested() + " basarili");
        auditWriter.bulkItems(req, SecurityContextHolder.getContext().getAuthentication(), r.action(), reason, res.items());
        return res;
    }

    // ---- ic yardimcilar ----

    private void stream(HttpServletResponse res, String filename, Long eventId, ToIntFunction<Writer> body) throws IOException {
        res.setStatus(HttpStatus.OK.value());
        res.setContentType("text/csv; charset=UTF-8");
        res.setHeader(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"");
        res.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        int n = 0;
        // try-with-resources KULLANILMAZ: dogrulama hatasinda yazici kapanirsa bos 200 yanit kesinlesirdi.
        Writer w = new BufferedWriter(new OutputStreamWriter(res.getOutputStream(), StandardCharsets.UTF_8));
        try {
            n = body.applyAsInt(w);
            w.flush();
            w.close();
        } catch (UncheckedIOException e) {
            throw e.getCause();
        } catch (RuntimeException e) {
            if (!res.isCommitted()) {
                res.reset(); // henuz hicbir sey yazilmadiysa normal JSON hata yaniti verilsin
            }
            throw e;
        } finally {
            AuditContext.target("EVENT", eventId).summary("csv satir=" + n);
        }
    }

    private void readLimit() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        limiter.check("adminevents-ops:" + (a == null ? "anon" : a.getName()), READ_PER_MINUTE, Duration.ofMinutes(1));
    }

    /** Govdedeki sebep; yoksa X-Admin-Reason basligindan AdminReasonFilter'in koydugu sebep. */
    private static String reason(ReasonBody body) {
        return body != null && body.reason() != null && !body.reason().isBlank() ? body.reason() : AuditContext.currentReason();
    }

    /** JWT yoneticisinin id'si; Basic auth yoneticisinde kullanici kaydi yoktur (null). */
    private static Long adminId() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long id ? id : null;
    }
}
