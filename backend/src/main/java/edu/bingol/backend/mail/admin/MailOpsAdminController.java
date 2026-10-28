package edu.bingol.backend.mail.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.AuditRead;
import edu.bingol.backend.admin.Csv;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.mail.MailCategory;
import edu.bingol.backend.mail.MailStatus;
import edu.bingol.backend.mail.MailTemplate;
import edu.bingol.backend.mail.SuppressionReason;
import edu.bingol.backend.mail.admin.MailOpsDtos.BulkRequest;
import edu.bingol.backend.mail.admin.MailOpsDtos.BulkResult;
import edu.bingol.backend.mail.admin.MailOpsDtos.OutboxDetail;
import edu.bingol.backend.mail.admin.MailOpsDtos.OutboxRow;
import edu.bingol.backend.mail.admin.MailOpsDtos.PageResult;
import edu.bingol.backend.mail.admin.MailOpsDtos.QuotaView;
import edu.bingol.backend.mail.admin.MailOpsDtos.SuppressionCreate;
import edu.bingol.backend.mail.admin.MailOpsDtos.SuppressionDetail;
import edu.bingol.backend.mail.admin.MailOpsDtos.SuppressionRow;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Arrays;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici mail altyapisi (P13; `/api/admin/**` yalniz ADMIN): bastirma listesi, mail kuyrugu ve gunluk kota.
 * Yazma uclari SEBEP ister (AdminGuardPolicy) ve AuditContext ile (MAIL_SUPPRESSION / MAIL_OUTBOX) denetlenir.
 * Kisisel veri okuyan ayrinti uclari {@link AuditRead} ile kayda gecer; listeler maskelidir.
 */
@RestController
@RequestMapping("/api/admin/mail")
public class MailOpsAdminController {

    public static final String CONFIRM_HEADER = "X-Admin-Confirm";
    private static final ZoneId ZONE = ZoneId.of("Europe/Istanbul");
    private static final List<String> CSV_HEADER =
            Arrays.asList("id", "adresMaskeli", "ozetOnEki", "sebep", "kategori", "not", "olusturma", "ekleyenId");

    private final MailSuppressionAdminService suppressions;
    private final MailOutboxAdminService outbox;
    private final MailQuotaAdminService quota;
    private final RateLimiter limiter;

    public MailOpsAdminController(MailSuppressionAdminService suppressions, MailOutboxAdminService outbox,
                                  MailQuotaAdminService quota, RateLimiter limiter) {
        this.suppressions = suppressions;
        this.outbox = outbox;
        this.quota = quota;
        this.limiter = limiter;
    }

    // ------------------------------------------------------------------ bastirma

    /** q: tam e-posta, 64 haneli ozet ya da kayitli kullanici adresinde parca (>= 3 karakter). from/to gun (Europe/Istanbul). */
    @GetMapping("/suppressions")
    public PageResult<SuppressionRow> suppressions(@RequestParam(required = false) SuppressionReason reason,
                                                   @RequestParam(required = false) MailCategory category,
                                                   @RequestParam(required = false) String q,
                                                   @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                                   @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                                   @RequestParam(defaultValue = "0") int page,
                                                   @RequestParam(defaultValue = "20") int size) {
        return suppressions.list(reason, category, q, start(from), endExclusive(to), page, size);
    }

    /** Ayrinti: tam adres yalniz bir kullanici hesabi ozetle eslesiyorsa. Kisisel veri okur: denetlenir. */
    @AuditRead
    @GetMapping("/suppressions/{id}")
    public SuppressionDetail suppression(@PathVariable Long id) {
        AuditContext.target("MAIL_SUPPRESSION", id);
        return suppressions.detail(id);
    }

    /** Elle ekleme: not (sebep) zorunlu; govdedeki reason yalniz MANUAL olabilir. */
    @PostMapping("/suppressions")
    @ResponseStatus(HttpStatus.CREATED)
    public SuppressionRow addSuppression(@Valid @RequestBody SuppressionCreate r, Authentication auth) {
        return suppressions.addManual(r, adminId(auth));
    }

    /**
     * Kaldirma (geri alinamaz). UNSUBSCRIBED/COMPLAINT: `X-Admin-Confirm: &lt;id&gt;` + sebep &gt;= 20 (yoksa 409
     * MAILOPS_USER_OPTED_OUT); BOUNCED/MANUAL: sebep &gt;= 5.
     */
    @DeleteMapping("/suppressions/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeSuppression(@PathVariable Long id,
                                  @RequestHeader(value = CONFIRM_HEADER, required = false) String confirm) {
        AuditContext.target("MAIL_SUPPRESSION", id);
        suppressions.remove(id, AuditContext.currentReason(), confirm);
    }

    /** CSV: maskeli adres, en cok 50 bin satir, formul kacisli; denetlenir (yol `/export.csv`). */
    @GetMapping("/suppressions/export.csv")
    public void suppressionsCsv(@RequestParam(required = false) SuppressionReason reason,
                                @RequestParam(required = false) MailCategory category,
                                @RequestParam(required = false) String q,
                                @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                HttpServletResponse res) throws IOException {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        String actor = a != null && a.getPrincipal() instanceof Long id ? String.valueOf(id) : "basic";
        limiter.check("admcsv:" + actor, 10, Duration.ofMinutes(1));
        List<SuppressionRow> rows = suppressions.exportRows(reason, category, q, start(from), endExclusive(to));
        AuditContext.target("MAIL_SUPPRESSION", null).summary("csv satir=" + rows.size());
        res.setStatus(HttpStatus.OK.value());
        res.setContentType("text/csv; charset=UTF-8");
        res.setHeader(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"mail-bastirma.csv\"");
        res.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        try (Writer w = new BufferedWriter(new OutputStreamWriter(res.getOutputStream(), StandardCharsets.UTF_8))) {
            w.write(Csv.BOM);
            w.write(Csv.row(CSV_HEADER));
            for (SuppressionRow r : rows) {
                w.write(Csv.row(Arrays.<Object>asList(r.id(), r.emailMasked(), r.hashPrefix(), r.reason(), r.category(),
                        r.note(), r.createdAt(), r.createdBy())));
            }
            w.flush();
        }
    }

    // ------------------------------------------------------------------ kuyruk

    /** q: tam e-posta, '@alan' ya da kayit numarasi. Alici maskeli doner; icerik yoktur. */
    @GetMapping("/outbox")
    public PageResult<OutboxRow> outbox(@RequestParam(required = false) MailStatus status,
                                        @RequestParam(required = false) MailTemplate template,
                                        @RequestParam(required = false) MailCategory category,
                                        @RequestParam(required = false) String q,
                                        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                        @RequestParam(defaultValue = "0") int page,
                                        @RequestParam(defaultValue = "20") int size) {
        return outbox.list(status, template, category, q, start(from), endExclusive(to), page, size);
    }

    /** Ayrinti: durum gecmisi, deneme, hata, sonraki deneme. ICERIK/DEGISKEN DONMEZ. */
    @AuditRead
    @GetMapping("/outbox/{id}")
    public OutboxDetail outboxDetail(@PathVariable Long id) {
        AuditContext.target("MAIL_OUTBOX", id);
        return outbox.detail(id);
    }

    /** DEAD/SKIPPED -> PENDING. Icerik yeniden uretilemiyorsa (kod postasi, silinmis degisken) 409. Sebep zorunlu. */
    @PostMapping("/outbox/{id}/retry")
    public OutboxDetail retry(@PathVariable Long id) {
        return outbox.retry(id);
    }

    /** PENDING/FAILED -> SKIPPED (geri alinamaz). Sebep zorunlu. */
    @PostMapping("/outbox/{id}/cancel")
    public OutboxDetail cancel(@PathVariable Long id) {
        return outbox.cancel(id);
    }

    /** Toplu: action RETRY|CANCEL, en cok 200 kimlik, sebep zorunlu; kismi basari (failed[] kodlariyla). */
    @PostMapping("/outbox/bulk")
    public BulkResult bulk(@Valid @RequestBody BulkRequest r) {
        return outbox.bulk(r.action(), r.ids());
    }

    // ------------------------------------------------------------------ kota

    @GetMapping("/quota")
    public QuotaView quota() {
        return quota.view();
    }

    // ------------------------------------------------------------------ yardimcilar

    private static Instant start(LocalDate d) {
        return d == null ? null : d.atStartOfDay(ZONE).toInstant();
    }

    private static Instant endExclusive(LocalDate d) {
        return d == null ? null : d.plusDays(1).atStartOfDay(ZONE).toInstant();
    }

    static Long adminId(Authentication auth) {
        return auth != null && auth.getPrincipal() instanceof Long l ? l : null;
    }
}
