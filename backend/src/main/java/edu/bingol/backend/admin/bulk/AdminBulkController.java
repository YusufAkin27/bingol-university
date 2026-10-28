package edu.bingol.backend.admin.bulk;

import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.AuditRead;
import edu.bingol.backend.admin.bulk.BulkDtos.AcademicBulkRequest;
import edu.bingol.backend.admin.bulk.BulkDtos.AcademicEntity;
import edu.bingol.backend.admin.bulk.BulkDtos.MenuBulkDeleteRequest;
import edu.bingol.backend.admin.bulk.BulkDtos.NewsBulkRequest;
import edu.bingol.backend.admin.bulk.BulkDtos.PendingBulkCancelRequest;
import edu.bingol.backend.admin.bulk.BulkDtos.Report;
import edu.bingol.backend.admin.bulk.BulkDtos.SourceSyncRequest;
import edu.bingol.backend.admin.bulk.BulkDtos.SourcesStatus;
import edu.bingol.backend.admin.bulk.BulkDtos.SyncResult;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.menu.MenuAdminService;
import edu.bingol.backend.news.ContentType;
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
import java.time.LocalDate;
import java.util.List;
import java.util.function.ToIntFunction;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * P15 yonetici toplu islemleri ve disa aktarma (yalniz ADMIN: /api/admin/** SecurityConfig). Yazma uclari SEBEP ister
 * (AdminGuardPolicy; burada da dogrulanir), yikici sayilir (saatlik siki sinir) ve kismi basari raporu doner:
 * {requested, done, skipped, failed, results[]}. Sinirlar: 200 kayit (haber/akademik/bekleyen), 62 gun (menu).
 * Mevcut controller'lara dokunulmaz; mevcut tekil uclar degismeden calisir.
 */
@RestController
@RequestMapping("/api/admin")
public class AdminBulkController {

    private static final int CSV_PER_MINUTE = 10;

    private final NewsBulkService news;
    private final AcademicBulkService academic;
    private final MenuBulkService menu;
    private final PendingBulkService pending;
    private final BulkCsvService csv;
    private final SourcesService sources;
    private final BulkAuditWriter audit;
    private final RateLimiter limiter;

    public AdminBulkController(NewsBulkService news, AcademicBulkService academic, MenuBulkService menu,
                               PendingBulkService pending, BulkCsvService csv, SourcesService sources,
                               BulkAuditWriter audit, RateLimiter limiter) {
        this.news = news;
        this.academic = academic;
        this.menu = menu;
        this.pending = pending;
        this.csv = csv;
        this.sources = sources;
        this.audit = audit;
        this.limiter = limiter;
    }

    // ---- haber ----

    /** POST /api/admin/news/bulk {action: HIDE|UNHIDE, ids (en cok 200), reason}. */
    @PostMapping("/news/bulk")
    public Report newsBulk(@Valid @RequestBody NewsBulkRequest r, HttpServletRequest req) {
        List<Long> ids = BulkSupport.distinct(r.ids(), BulkDtos.MAX_IDS);
        String reason = BulkSupport.reason(r.reason());
        AuditContext.target("NEWS", null).reason(reason);
        Report rep = news.run(r.action(), ids);
        summary("haber " + r.action(), rep);
        audit.items(req, "NEWS", "/api/admin/news", BulkSupport.lower(r.action()), reason, rep.results());
        return rep;
    }

    /** GET /api/admin/news/export.csv?q=&type=&hidden= (liste ile ayni suzgecler; en cok 50.000 satir). */
    @GetMapping("/news/export.csv")
    public void newsCsv(@RequestParam(required = false) String q, @RequestParam(required = false) ContentType type,
                        @RequestParam(required = false) Boolean hidden, HttpServletResponse res) throws IOException {
        csvLimit();
        stream(res, "news.csv", "NEWS", w -> csv.news(q, type, hidden, w));
    }

    // ---- akademik ----

    /** POST /api/admin/academic/bulk {entity: CALENDAR|EXAM|ANNOUNCEMENT, action: PUBLISH|UNPUBLISH|DELETE, ids, reason}. */
    @PostMapping("/academic/bulk")
    public Report academicBulk(@Valid @RequestBody AcademicBulkRequest r, HttpServletRequest req) {
        List<Long> ids = BulkSupport.distinct(r.ids(), BulkDtos.MAX_IDS);
        String reason = BulkSupport.reason(r.reason());
        AuditContext.target("ACADEMIC_" + r.entity(), null).reason(reason);
        Report rep = academic.run(r.entity(), r.action(), ids);
        summary(r.entity() + " " + r.action(), rep);
        audit.items(req, "ACADEMIC_" + r.entity(), "/api/admin/academic/" + BulkSupport.lower(r.entity()),
                BulkSupport.lower(r.action()), reason, rep.results());
        return rep;
    }

    /**
     * GET /api/admin/academic/export.csv?entity=CALENDAR|EXAM|ANNOUNCEMENT&q=&kind=&published=&status=
     * (kind/published yalniz CALENDAR, status yalniz ANNOUNCEMENT).
     */
    @GetMapping("/academic/export.csv")
    public void academicCsv(@RequestParam(required = false) AcademicEntity entity,
                            @RequestParam(required = false) String q, @RequestParam(required = false) String kind,
                            @RequestParam(required = false) Boolean published,
                            @RequestParam(required = false) String status, HttpServletResponse res) throws IOException {
        if (entity == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EXPORT_ENTITY_INVALID",
                    "Dışa aktarılacak tür belirtilmeli (CALENDAR, EXAM, ANNOUNCEMENT).");
        }
        csvLimit();
        stream(res, "academic-" + BulkSupport.lower(entity) + ".csv", "ACADEMIC_" + entity,
                w -> csv.academic(entity, q, kind, published, status, w));
    }

    // ---- menu ----

    /** POST /api/admin/menu/bulk-delete {dates (yyyy-MM-dd, en cok 62), reason}: gun satiri + gorsel dosyasi. */
    @PostMapping("/menu/bulk-delete")
    public Report menuBulkDelete(@Valid @RequestBody MenuBulkDeleteRequest r, HttpServletRequest req) {
        List<String> raw = BulkSupport.distinct(r.dates(), BulkDtos.MAX_DATES);
        List<LocalDate> dates = MenuBulkService.parse(raw);
        String reason = BulkSupport.reason(r.reason());
        AuditContext.target("MENU", null).reason(reason);
        Report rep = menu.delete(dates);
        summary("menu silme", rep);
        audit.items(req, "MENU", "/api/admin/menu", "delete", reason, rep.results());
        return rep;
    }

    /** GET /api/admin/menu/export.csv?from=&to= (yyyy-MM-dd; bos = tum gunler). */
    @GetMapping("/menu/export.csv")
    public void menuCsv(@RequestParam(required = false) String from, @RequestParam(required = false) String to,
                        HttpServletResponse res) throws IOException {
        LocalDate f = from == null || from.isBlank() ? null : MenuAdminService.parseDate(from);
        LocalDate t = to == null || to.isBlank() ? null : MenuAdminService.parseDate(to);
        csvLimit();
        stream(res, "menu.csv", "MENU", w -> csv.menu(f, t, w));
    }

    // ---- bekleyen kayit ----

    /** POST /api/admin/pending-registrations/bulk-cancel {emails (e-posta ya da okul numarasi, en cok 200), reason}. */
    @PostMapping("/pending-registrations/bulk-cancel")
    public Report pendingBulkCancel(@Valid @RequestBody PendingBulkCancelRequest r, HttpServletRequest req) {
        List<String> raw = BulkSupport.distinct(r.emails(), BulkDtos.MAX_IDS);
        List<String> emails = PendingBulkService.normalize(raw);
        String reason = BulkSupport.reason(r.reason());
        AuditContext.target("PENDING_REGISTRATION", null).reason(reason);
        Report rep = pending.cancel(emails);
        summary("bekleyen kayit iptali", rep);
        audit.items(req, "PENDING_REGISTRATION", "/api/admin/pending-registrations", "cancel", reason, rep.results());
        return rep;
    }

    /** GET /api/admin/pending-registrations/export.csv?q= (e-posta ve ad maskeli; kisisel veri okuma: denetim kaydina yazilir). */
    @AuditRead
    @GetMapping("/pending-registrations/export.csv")
    public void pendingCsv(@RequestParam(required = false) String q, HttpServletResponse res) throws IOException {
        csvLimit();
        stream(res, "pending-registrations.csv", "PENDING_REGISTRATION", w -> csv.pending(q, w));
    }

    // ---- kaynaklar ----

    /** GET /api/admin/sources/status: haber ve menu kaynaginin durumu (yalniz toplulastirma; kaynak siteye istek yok). */
    @GetMapping("/sources/status")
    public SourcesStatus sourcesStatus() {
        return sources.status();
    }

    /**
     * POST /api/admin/sources/sync {source: NEWS|MENU, reason}: elle senkron (kaynak siteye istek atar; scraper
     * kurali: gunluk yalniz zamanlayici, bu bir istisnadir). Saatte 3 (kaynak basina ortak); asilirsa 429.
     */
    @PostMapping("/sources/sync")
    public SyncResult sourcesSync(@Valid @RequestBody SourceSyncRequest r) {
        String reason = BulkSupport.reason(r.reason());
        AuditContext.target("SOURCE", r.source()).reason(reason);
        SyncResult res = sources.sync(r.source());
        AuditContext.summary("elle senkron " + r.source() + ": " + res.changed() + " degisiklik");
        return res;
    }

    // ---- ic yardimcilar ----

    private static void summary(String what, Report rep) {
        AuditContext.summary("toplu " + what + ": " + rep.done() + "/" + rep.requested() + " basarili, "
                + rep.skipped() + " atlandi, " + rep.failed() + " hata");
    }

    private void csvLimit() {
        limiter.check("adminbulk-csv:" + BulkSupport.actor(), CSV_PER_MINUTE, Duration.ofMinutes(1));
    }

    private void stream(HttpServletResponse res, String filename, String targetType, ToIntFunction<Writer> body)
            throws IOException {
        res.setStatus(HttpStatus.OK.value());
        res.setContentType("text/csv; charset=UTF-8");
        res.setHeader(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"");
        res.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        int n = 0;
        // try-with-resources KULLANILMAZ: hata aninda yazici kapanirsa bos 200 yanit kesinlesirdi.
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
            AuditContext.target(targetType, null).summary("csv satir=" + n);
        }
    }
}
