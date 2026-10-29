package edu.bingol.backend.dbmaint.admin;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.rbac.AdminPermissionContext;
import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.dbmaint.admin.RetentionDtos.ExportRequest;
import edu.bingol.backend.dbmaint.admin.RetentionDtos.PurgePreview;
import edu.bingol.backend.dbmaint.admin.RetentionDtos.PurgeRequest;
import edu.bingol.backend.dbmaint.admin.RetentionDtos.PurgeView;
import edu.bingol.backend.dbmaint.admin.RetentionDtos.ReceiptView;
import edu.bingol.backend.dbmaint.admin.RetentionDtos.TableInfo;
import edu.bingol.backend.dbmaint.admin.RetentionTables.Spec;
import edu.bingol.backend.observability.StorageUsageService;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.io.IOException;
import java.time.Duration;
import java.time.LocalDate;
import java.util.List;
import java.util.regex.Pattern;
import org.slf4j.MDC;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
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
 * Veri saklama (DS1): depolama doluluk raporu, sisen log tablolarini dışa aktarma (makbuzlu) ve onayli temizlik.
 * Izinler `AdminPermissionPolicy`: okuma {@code data.retention.read}, dışa aktarma {@code data.retention.export},
 * silme {@code data.retention.purge} (ikisi yalniz FULL). Sozlesme: docs/ADMIN_API.md "Veri saklama (DS1)".
 */
@RestController
@RequestMapping("/api/admin")
public class RetentionAdminController {

    public static final int PURGE_MIN_REASON = 10;
    public static final int FORCE_MIN_REASON = 20;
    private static final Pattern IDEM_KEY = Pattern.compile("[A-Za-z0-9._:-]{8,100}");

    private final RetentionService service;
    private final RetentionExportService exports;
    private final RetentionPurgeService purges;
    private final DataExportReceiptRepository receipts;
    private final StorageUsageService storage;
    private final RateLimiter limiter;
    private final JdbcTemplate jdbc;

    public RetentionAdminController(RetentionService service, RetentionExportService exports,
                                    RetentionPurgeService purges, DataExportReceiptRepository receipts,
                                    StorageUsageService storage, RateLimiter limiter, JdbcTemplate jdbc) {
        this.service = service;
        this.exports = exports;
        this.purges = purges;
        this.receipts = receipts;
        this.storage = storage;
        this.limiter = limiter;
        this.jdbc = jdbc;
    }

    // ---- doluluk ----

    @GetMapping("/system/storage")
    public StorageUsageService.Report storage() {
        limiter.check("admin:retention:read:" + actorKey(), 120, Duration.ofMinutes(1));
        return storage.report();
    }

    // ---- envanter / onizleme ----

    @GetMapping("/data-retention/tables")
    public List<TableInfo> tables() {
        limiter.check("admin:retention:read:" + actorKey(), 120, Duration.ofMinutes(1));
        return service.tables();
    }

    @GetMapping("/data-retention/tables/{table}/purge-preview")
    public PurgePreview preview(@PathVariable String table, @RequestParam(required = false) LocalDate from,
                                @RequestParam LocalDate to) {
        limiter.check("admin:retention:preview:" + actorKey(), 60, Duration.ofMinutes(1));
        Spec spec = service.requireSpec(table);
        return service.preview(spec, service.resolveRange(spec, from, to));
    }

    // ---- disa aktarma ----

    /**
     * Akisli gzip'li CSV indirme. Makbuz kimligi {@code X-Export-Receipt-Id} basliginda; satir sayisi ve SHA-256
     * akis bitince makbuza yazilir ({@code GET /data-retention/exports/{id}}).
     */
    @PostMapping("/data-retention/exports")
    public void export(@Valid @RequestBody ExportRequest req, HttpServletResponse res) throws IOException {
        Long adminId = adminId();
        Spec spec = service.requireSpec(req.table());
        RetentionService.Range range = service.resolveRange(spec, req.from(), req.to());
        String reason = reason(req.reason());
        // Hiz siniri dogrulamadan SONRA: gecersiz denemeler saatlik kotayi tuketmez
        limiter.check("admin:retention:export:" + actorKey(), 5, Duration.ofHours(1));
        RetentionExportService.Started st = exports.begin(spec, range, adminId, adminEmail(adminId), reason,
                MDC.get("requestId"));
        AuditContext.target("RETENTION_EXPORT", st.receipt().getId()).reason(reason);
        java.io.OutputStream out;
        try {
            res.setStatus(HttpStatus.OK.value());
            res.setContentType("application/gzip");
            res.setHeader(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + spec.name() + "_"
                    + range.from() + "_" + range.toExclusive() + ".csv.gz\"");
            res.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
            res.setHeader("X-Export-Receipt-Id", String.valueOf(st.receipt().getId()));
            out = res.getOutputStream();
        } catch (IOException | RuntimeException e) {
            exports.abort(st); // akis baslamadi: yuvayi birak, makbuz FAILED
            throw e;
        }
        // stream() hatada kendi yuvasini birakir ve makbuzu FAILED yapar
        DataExportReceipt done = exports.stream(st, out);
        AuditContext.summary(spec.name() + " " + range.from() + ".." + range.toExclusive() + " satir="
                + done.getRowCount() + " sha256=" + (done.getSha256() == null ? "-" : done.getSha256().substring(0, 12)));
    }

    @GetMapping("/data-retention/exports")
    public List<ReceiptView> exportList(@RequestParam(required = false) String table) {
        limiter.check("admin:retention:read:" + actorKey(), 120, Duration.ofMinutes(1));
        List<DataExportReceipt> rows = table == null || table.isBlank() ? receipts.findTop50ByOrderByIdDesc()
                : receipts.findTop50ByTableNameOrderByIdDesc(service.requireSpec(table).name());
        return rows.stream().map(RetentionService::view).toList();
    }

    @GetMapping("/data-retention/exports/{id}")
    public ReceiptView exportOne(@PathVariable long id) {
        limiter.check("admin:retention:read:" + actorKey(), 120, Duration.ofMinutes(1));
        return receipts.findById(id).map(RetentionService::view).orElseThrow(() -> new ApiException(
                HttpStatus.NOT_FOUND, "RETENTION_RECEIPT_NOT_FOUND", "Makbuz bulunamadı."));
    }

    // ---- silme ----

    /**
     * Onayli silme: gerekce zorunlu, tablo adi yazarak onay, {@code Idempotency-Key} zorunlu, yalniz asgari saklama
     * suresinden eski kayitlar, kapsayan TAMAMLANMIS makbuz olmadan reddedilir. {@code forceWithoutExport} yalniz FULL
     * profil ve en az 20 karakter gerekcesiyle. Is arka planda yurur: 202 + durum kaydi.
     */
    @PostMapping("/data-retention/purges")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public PurgeView purge(@Valid @RequestBody PurgeRequest req,
                           @RequestHeader(value = "Idempotency-Key", required = false) String idemKey) {
        if (idemKey == null || !IDEM_KEY.matcher(idemKey.trim()).matches()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "RETENTION_IDEMPOTENCY_REQUIRED",
                    "Silme isteği için Idempotency-Key başlığı zorunludur.");
        }
        Long adminId = adminId();
        Spec spec = service.requireSpec(req.table());
        if (!spec.deletable()) {
            throw new ApiException(HttpStatus.CONFLICT, "RETENTION_TABLE_NOT_DELETABLE",
                    "Bu tablo panelden silinemez; yalnız dışa aktarılabilir.");
        }
        if (!spec.name().equals(req.confirmTable() == null ? null : req.confirmTable().trim())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "RETENTION_CONFIRM_MISMATCH",
                    "Onay için tablo adını aynen yazın.");
        }
        RetentionService.Range range = service.resolveRange(spec, req.from(), req.to());
        boolean forced = Boolean.TRUE.equals(req.forceWithoutExport());
        String reason = reason(req.reason());
        if (reason.length() < PURGE_MIN_REASON) {
            throw reasonShort(PURGE_MIN_REASON);
        }
        DataExportReceipt receipt = null;
        long[] count = service.countCapped(spec, range);
        if (forced) {
            AdminPermissionContext ctx = AdminPermissionContext.current();
            if (ctx != null && ctx.profile() != AdminProfile.FULL) {
                throw new ApiException(HttpStatus.FORBIDDEN, "RETENTION_FORCE_FORBIDDEN",
                        "Makbuzsuz silme yalnız tam yetkili (FULL) yöneticiye açıktır.");
            }
            if (reason.length() < FORCE_MIN_REASON) {
                throw reasonShort(FORCE_MIN_REASON);
            }
        } else {
            receipt = service.coveringReceipt(spec, range, req.receiptId());
            if (receipt == null) {
                throw new ApiException(HttpStatus.CONFLICT, "RETENTION_EXPORT_REQUIRED",
                        "Bu aralık için tamamlanmış bir dışa aktarma makbuzu yok; önce dışa aktarın.");
            }
            if (count[0] + count[1] > receipt.getRowCount()) {
                throw new ApiException(HttpStatus.CONFLICT, "RETENTION_RECEIPT_STALE",
                        "Aralıkta makbuzdan sonra yeni kayıtlar var; yeniden dışa aktarın.");
            }
        }
        if (count[0] == 0) {
            throw new ApiException(HttpStatus.CONFLICT, "RETENTION_NOTHING_TO_DELETE",
                    "Bu aralıkta silinecek kayıt yok.");
        }
        // Hiz siniri dogrulamadan SONRA: reddedilen denemeler saatlik kotayi tuketmez (gercek silmeler 10/saat)
        limiter.check("admin:retention:purge:" + actorKey(), 10, Duration.ofHours(1));
        PurgeView v = purges.start(spec, range, receipt, forced, count[0], reason, adminId, adminEmail(adminId),
                MDC.get("requestId"));
        AuditContext.target("RETENTION_PURGE", v.id()).reason(reason).summary(spec.name() + " " + range.from() + ".."
                + range.toExclusive() + " tahmini=" + count[0] + (forced ? " ZORLA(makbuzsuz)" : " makbuz=" + v.receiptId()));
        return v;
    }

    @GetMapping("/data-retention/purges")
    public List<PurgeView> purgeList() {
        limiter.check("admin:retention:read:" + actorKey(), 120, Duration.ofMinutes(1));
        return purges.recent();
    }

    @GetMapping("/data-retention/purges/{id}")
    public PurgeView purgeOne(@PathVariable long id) {
        limiter.check("admin:retention:read:" + actorKey(), 240, Duration.ofMinutes(1));
        return purges.get(id);
    }

    // ---- yardimcilar ----

    private static String reason(String bodyReason) {
        String r = AuditContext.currentReason();
        if (r == null || r.isBlank()) {
            r = bodyReason;
        }
        r = r == null ? "" : r.strip();
        if (r.length() < 5) {
            throw reasonShort(5);
        }
        return r;
    }

    private static ApiException reasonShort(int min) {
        return new ApiException(HttpStatus.BAD_REQUEST, "REASON_REQUIRED",
                "Bu işlem için gerekçe zorunludur (en az " + min + " karakter).", String.valueOf(min));
    }

    private static Long adminId() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long id ? id : null;
    }

    private static String actorKey() {
        Long id = adminId();
        return id == null ? "basic" : String.valueOf(id);
    }

    private String adminEmail(Long id) {
        if (id == null) {
            return "basic-admin";
        }
        try {
            return jdbc.queryForObject("SELECT email FROM app_user WHERE id = ?", String.class, id);
        } catch (RuntimeException e) {
            return null;
        }
    }
}
