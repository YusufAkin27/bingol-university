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
    static final int CHUNK = 1000;
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
        Specification<Report> spec = reportSpec(status, targetType, resolution, reasonCode, AdminDates.from(from),
                AdminDates.toExclusive(to));
        int[] n = {0};
        try {
            // FIX-P05 (A05#9): 1000'lik kimlik imecli sayfalarla dogrudan yanita yazilir (50.000 varlik bellekte tutulmaz)
            stream(res, "raporlar.csv", REPORT_HEADER, w -> n[0] = pump(reports, spec, Report::getId, r ->
                    writeRow(w, Arrays.<Object>asList(r.getId(), r.getStatus(), r.getResolution(), r.getReasonCode(),
                            r.getReporterId(), r.getTargetType(), r.getTargetId(), r.getReason(), r.getNote(),
                            r.getPriority(), r.getCreatedAt(), r.getResolvedAt(), r.getResolvedBy()))));
        } finally {
            AuditContext.target("REPORT", null).summary("csv satir=" + n[0]);
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
        Specification<ModerationAppeal> spec = appealSpec(status, targetType, AdminDates.from(from),
                AdminDates.toExclusive(to));
        int[] n = {0};
        try {
            stream(res, "itirazlar.csv", APPEAL_HEADER, w -> n[0] = pump(appeals, spec, ModerationAppeal::getId, a ->
                    writeRow(w, Arrays.<Object>asList(a.getId(), a.getStatus(), a.getUserId(), a.getTargetType(),
                            a.getTargetId(), a.getMessage(), a.getAdminNote(), a.getCreatedAt(), a.getDecidedAt(),
                            a.getDecidedBy()))));
        } finally {
            AuditContext.target("APPEAL", null).summary("csv satir=" + n[0]);
        }
    }

    Specification<Report> reportSpec(String status, ReportTargetType type, Report.Resolution resolution, String reasonCode,
                                     Instant from, Instant toExclusive) {
        return (root, q, cb) -> {
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
    }

    Specification<ModerationAppeal> appealSpec(String status, ReportTargetType type, Instant from, Instant toExclusive) {
        return (root, q, cb) -> {
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
    }

    /** Yanita basligi yazar, govdeyi {@code body} ile akitir. */
    static void stream(HttpServletResponse res, String filename, List<String> header, java.util.function.Consumer<Writer> body)
            throws IOException {
        res.setStatus(HttpStatus.OK.value());
        res.setContentType("text/csv; charset=UTF-8");
        res.setHeader(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"");
        res.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        try (Writer w = new BufferedWriter(new OutputStreamWriter(res.getOutputStream(), StandardCharsets.UTF_8))) {
            w.write(Csv.BOM);
            w.write(Csv.row(header));
            body.accept(w);
            w.flush();
        }
    }

    private static void writeRow(Writer w, List<Object> row) {
        try {
            w.write(Csv.row(row));
        } catch (IOException e) {
            throw new java.io.UncheckedIOException(e);
        }
    }

    /**
     * Kimlige gore azalan, {@value #CHUNK} satirlik imecli sayfalarla (COUNT yok) en cok {@value #MAX_ROWS} satiri
     * {@code out}'a verir. Doner: yazilan satir sayisi.
     */
    static <T> int pump(org.springframework.data.jpa.repository.JpaSpecificationExecutor<T> repo, Specification<T> base,
                        java.util.function.Function<T, Long> idOf, java.util.function.Consumer<T> out) {
        return pump(repo, base, idOf, out, CHUNK, MAX_ROWS);
    }

    static <T> int pump(org.springframework.data.jpa.repository.JpaSpecificationExecutor<T> repo, Specification<T> base,
                        java.util.function.Function<T, Long> idOf, java.util.function.Consumer<T> out,
                        int chunk, int max) {
        int n = 0;
        Long cursor = null;
        while (n < max) {
            int want = Math.min(chunk, max - n);
            final Long before = cursor;
            Specification<T> spec = before == null ? base
                    : base.and((root, q, cb) -> cb.lessThan(root.<Long>get("id"), before));
            List<T> rows = repo.findBy(spec, q -> q.sortBy(Sort.by(Sort.Direction.DESC, "id")).limit(want).all());
            if (rows.isEmpty()) {
                break;
            }
            for (T r : rows) {
                out.accept(r);
                n++;
            }
            cursor = idOf.apply(rows.get(rows.size() - 1));
            if (rows.size() < want) {
                break;
            }
        }
        return n;
    }

    /** CSV dokumu agir olabilir: yonetici basina dakikada 10. */
    private void limit() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        String actor = a != null && a.getPrincipal() instanceof Long id ? String.valueOf(id) : "basic";
        limiter.check("admcsv:" + actor, 10, Duration.ofMinutes(1));
    }
}
