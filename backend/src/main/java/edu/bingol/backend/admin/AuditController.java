package edu.bingol.backend.admin;

import edu.bingol.backend.admin.AdminDtos.AuditRow;
import edu.bingol.backend.admin.AdminDtos.MessageAccessRow;
import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.common.ApiException;
import jakarta.servlet.http.HttpServletResponse;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.UncheckedIOException;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.List;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yönetici işlemleri denetim kaydı (en yeni önce) + CSV dışa aktarımı + sohbet içeriği erişim kayıtları.
 * CSV ve erişim kayıtları listesi kendileri de denetlenir.
 */
@RestController
@RequestMapping("/api/admin")
public class AuditController {

    static final int CSV_MAX_ROWS = 50_000;
    private static final ZoneId ISTANBUL = ZoneId.of("Europe/Istanbul");
    static final List<String> CSV_HEADER = List.of("id", "at", "adminId", "adminEmail", "method", "path", "status",
            "targetType", "targetId", "reason", "summary", "requestId", "ip");

    private final AuditRepository repo;
    private final MessageAccessAuditReader messageAccess;

    public AuditController(AuditRepository repo, MessageAccessAuditReader messageAccess) {
        this.repo = repo;
        this.messageAccess = messageAccess;
    }

    /**
     * GET /api/admin/audit?page=&size=&adminId=&method=&q=&from=&to=&targetType=&targetId=&status=
     * from/to: yyyy-MM-dd (İstanbul günü; `to` o gün dahil) ya da ISO-8601 an. status: 403 ya da 4xx.
     */
    @GetMapping("/audit")
    public PageResponse<AuditRow> list(@RequestParam(required = false) Long adminId,
                                       @RequestParam(required = false) String method,
                                       @RequestParam(required = false) String q,
                                       @RequestParam(required = false) String from,
                                       @RequestParam(required = false) String to,
                                       @RequestParam(required = false) String targetType,
                                       @RequestParam(required = false) String targetId,
                                       @RequestParam(required = false) String status,
                                       @RequestParam(defaultValue = "0") int page,
                                       @RequestParam(defaultValue = "20") int size) {
        int s = Math.min(Math.max(size, 1), AdminUserService.MAX_PAGE_SIZE);
        int p = Math.max(page, 0);
        AuditRepository.Filter f = filter(adminId, method, q, from, to, targetType, targetId, status);
        return PageResponse.of(repo.page(f, p, s), p, s, repo.count(f));
    }

    /** Aynı süzgeçlerle CSV (UTF-8 BOM, formül kaçışlı, en çok 50.000 satır, akış halinde). Kendisi de denetlenir. */
    @GetMapping("/audit/export.csv")
    public void exportCsv(@RequestParam(required = false) Long adminId,
                          @RequestParam(required = false) String method,
                          @RequestParam(required = false) String q,
                          @RequestParam(required = false) String from,
                          @RequestParam(required = false) String to,
                          @RequestParam(required = false) String targetType,
                          @RequestParam(required = false) String targetId,
                          @RequestParam(required = false) String status,
                          HttpServletResponse res) throws IOException {
        AuditRepository.Filter f = filter(adminId, method, q, from, to, targetType, targetId, status);
        res.setStatus(HttpStatus.OK.value());
        res.setContentType("text/csv; charset=UTF-8");
        res.setHeader(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"admin-audit.csv\"");
        res.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        int[] n = {0};
        try (Writer w = new BufferedWriter(new OutputStreamWriter(res.getOutputStream(), StandardCharsets.UTF_8))) {
            w.write(Csv.BOM);
            w.write(Csv.row(CSV_HEADER));
            repo.stream(f, CSV_MAX_ROWS, r -> {
                try {
                    w.write(Csv.row(csvCells(r)));
                    n[0]++;
                } catch (IOException e) {
                    throw new UncheckedIOException(e);
                }
            });
            w.flush();
        } catch (UncheckedIOException e) {
            throw e.getCause();
        } finally {
            AuditContext.target("AUDIT", null).summary("csv satir=" + n[0]);
        }
    }

    /**
     * GET /api/admin/audit/message-access?adminId=&targetUserId=&conversationId=&kind=&q=&from=&to=&page=&size=
     * Yönetici sohbet içeriği erişim kayıtları (sebep, hedef kullanıcı, mesaj aralığı). İçerik dönmez.
     */
    @AuditRead
    @GetMapping("/audit/message-access")
    public PageResponse<MessageAccessRow> messageAccess(@RequestParam(required = false) Long adminId,
                                                        @RequestParam(required = false) Long targetUserId,
                                                        @RequestParam(required = false) Long conversationId,
                                                        @RequestParam(required = false) String kind,
                                                        @RequestParam(required = false) String q,
                                                        @RequestParam(required = false) String from,
                                                        @RequestParam(required = false) String to,
                                                        @RequestParam(defaultValue = "0") int page,
                                                        @RequestParam(defaultValue = "20") int size) {
        int s = Math.min(Math.max(size, 1), AdminUserService.MAX_PAGE_SIZE);
        int p = Math.max(page, 0);
        MessageAccessAuditReader.Filter f = new MessageAccessAuditReader.Filter(adminId, targetUserId, conversationId,
                kind, q, parseFrom(from), parseTo(to));
        return PageResponse.of(messageAccess.page(f, p, s), p, s, messageAccess.count(f));
    }

    private static AuditRepository.Filter filter(Long adminId, String method, String q, String from, String to,
                                                 String targetType, String targetId, String status) {
        return new AuditRepository.Filter(adminId, method, q, parseFrom(from), parseTo(to), targetType, targetId, status);
    }

    static List<String> csvCells(AuditRow r) {
        return java.util.Arrays.asList(String.valueOf(r.id()), r.at(), str(r.adminId()), r.adminEmail(), r.method(),
                r.path(), String.valueOf(r.status()), r.targetType(), r.targetId(), r.reason(), r.summary(),
                r.requestId(), r.ip());
    }

    private static String str(Object o) {
        return o == null ? null : o.toString();
    }

    /** Başlangıç (dahil): tarih -> İstanbul gün başı; an -> aynen. */
    static Instant parseFrom(String s) {
        return parse(s, false);
    }

    /** Bitiş (hariç üst sınır): tarih -> o günün SONU (ertesi gün başı); an -> aynen. */
    static Instant parseTo(String s) {
        return parse(s, true);
    }

    private static Instant parse(String s, boolean end) {
        if (s == null || s.isBlank()) {
            return null;
        }
        String v = s.trim();
        try {
            if (v.length() == 10) {
                LocalDate d = LocalDate.parse(v);
                return (end ? d.plusDays(1) : d).atStartOfDay(ISTANBUL).toInstant();
            }
            return Instant.parse(v);
        } catch (DateTimeParseException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz tarih.");
        }
    }
}
