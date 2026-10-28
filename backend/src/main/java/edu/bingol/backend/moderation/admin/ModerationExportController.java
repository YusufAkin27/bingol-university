package edu.bingol.backend.moderation.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.Csv;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.moderation.ModerationAppeal;
import edu.bingol.backend.moderation.ModerationAppealRepository;
import edu.bingol.backend.moderation.Report;
import edu.bingol.backend.moderation.ReportRepository;
import edu.bingol.backend.moderation.ReportTargetType;
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
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
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
 * Rapor ve itiraz CSV dokumu (P11): suzgecli, en cok {@value #MAX_ROWS} satir, UTF-8 BOM, formul kacisli (Csv).
 * Kullanici metinleri (not, mesaj) icerdigi icin hucre kacisi zorunludur. Istekler denetim kaydina yazilir.
 */
@RestController
@RequestMapping("/api/admin")
public class ModerationExportController {

    static final int MAX_ROWS = 50_000;
    private static final List<String> REPORT_HEADER = Arrays.asList("id", "durum", "karar", "nedenKodu", "raporlayanId",
            "hedefTuru", "hedefId", "sebep", "not", "oncelik", "olusturma", "cozumTarihi", "cozenId");
    private static final List<String> APPEAL_HEADER = Arrays.asList("id", "durum", "kullaniciId", "hedefTuru", "hedefId",
            "mesaj", "yoneticiNotu", "olusturma", "kararTarihi", "kararVerenId");

    private final ReportRepository reports;
    private final ModerationAppealRepository appeals;
    private final RateLimiter limiter;

    public ModerationExportController(ReportRepository reports, ModerationAppealRepository appeals, RateLimiter limiter) {
        this.reports = reports;
        this.appeals = appeals;
        this.limiter = limiter;
    }

    /** status=OPEN|RESOLVED|ALL (varsayilan ALL). */
    @GetMapping("/reports/export.csv")
    public void reportsCsv(@RequestParam(required = false) String status,
                           @RequestParam(required = false) ReportTargetType targetType,
                           @RequestParam(required = false) Report.Resolution resolution,
                           @RequestParam(required = false) String reasonCode,
                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                           HttpServletResponse res) throws IOException {
        limit();
        List<Report> rows = findReports(status, targetType, resolution, reasonCode, AdminDates.from(from),
                AdminDates.toExclusive(to));
        try {
            write(res, "raporlar.csv", REPORT_HEADER, rows.stream().map(r -> Arrays.<Object>asList(r.getId(),
                    r.getStatus(), r.getResolution(), r.getReasonCode(), r.getReporterId(), r.getTargetType(),
                    r.getTargetId(), r.getReason(), r.getNote(), r.getPriority(), r.getCreatedAt(), r.getResolvedAt(),
                    r.getResolvedBy())).toList());
        } finally {
            AuditContext.target("REPORT", null).summary("csv satir=" + rows.size());
        }
    }

    /** status=OPEN|ACCEPTED|REJECTED|ALL (varsayilan ALL). */
    @GetMapping("/appeals/export.csv")
    public void appealsCsv(@RequestParam(required = false) String status,
                           @RequestParam(required = false) ReportTargetType targetType,
                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                           HttpServletResponse res) throws IOException {
        limit();
        List<ModerationAppeal> rows = findAppeals(status, targetType, AdminDates.from(from), AdminDates.toExclusive(to));
        try {
            write(res, "itirazlar.csv", APPEAL_HEADER, rows.stream().map(a -> Arrays.<Object>asList(a.getId(),
                    a.getStatus(), a.getUserId(), a.getTargetType(), a.getTargetId(), a.getMessage(), a.getAdminNote(),
                    a.getCreatedAt(), a.getDecidedAt(), a.getDecidedBy())).toList());
        } finally {
            AuditContext.target("APPEAL", null).summary("csv satir=" + rows.size());
        }
    }

    List<Report> findReports(String status, ReportTargetType type, Report.Resolution resolution, String reasonCode,
                             Instant from, Instant toExclusive) {
        Specification<Report> spec = (root, q, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            if ("OPEN".equalsIgnoreCase(status)) {
                ps.add(cb.equal(root.get("status"), Report.Status.OPEN));
            } else if ("RESOLVED".equalsIgnoreCase(status)) {
                ps.add(cb.equal(root.get("status"), Report.Status.RESOLVED));
            }
            if (type != null) {
                ps.add(cb.equal(root.get("targetType"), type));
            }
            if (resolution != null) {
                ps.add(cb.equal(root.get("resolution"), resolution));
            }
            if (reasonCode != null && !reasonCode.isBlank()) {
                ps.add(cb.equal(root.get("reasonCode"), reasonCode.trim().toUpperCase(java.util.Locale.ROOT)));
            }
            if (from != null) {
                ps.add(cb.greaterThanOrEqualTo(root.<Instant>get("createdAt"), from));
            }
            if (toExclusive != null) {
                ps.add(cb.lessThan(root.<Instant>get("createdAt"), toExclusive));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };
        return reports.findAll(spec, PageRequest.of(0, MAX_ROWS, Sort.by(Sort.Direction.DESC, "id"))).getContent();
    }

    List<ModerationAppeal> findAppeals(String status, ReportTargetType type, Instant from, Instant toExclusive) {
        Specification<ModerationAppeal> spec = (root, q, cb) -> {
            List<Predicate> ps = new ArrayList<>();
            for (ModerationAppeal.Status s : ModerationAppeal.Status.values()) {
                if (s.name().equalsIgnoreCase(status)) {
                    ps.add(cb.equal(root.get("status"), s));
                }
            }
            if (type != null) {
                ps.add(cb.equal(root.get("targetType"), type));
            }
            if (from != null) {
                ps.add(cb.greaterThanOrEqualTo(root.<Instant>get("createdAt"), from));
            }
            if (toExclusive != null) {
                ps.add(cb.lessThan(root.<Instant>get("createdAt"), toExclusive));
            }
            return cb.and(ps.toArray(new Predicate[0]));
        };
        return appeals.findAll(spec, PageRequest.of(0, MAX_ROWS, Sort.by(Sort.Direction.DESC, "id"))).getContent();
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

    /** CSV dokumu agir olabilir: yonetici basina dakikada 10. */
    private void limit() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        String actor = a != null && a.getPrincipal() instanceof Long id ? String.valueOf(id) : "basic";
        limiter.check("admcsv:" + actor, 10, Duration.ofMinutes(1));
    }
}
