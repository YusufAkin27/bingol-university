package edu.bingol.backend.notification.admin;

import edu.bingol.backend.admin.AdminDtos.PageResponse;
import edu.bingol.backend.admin.AdminReasonRequired;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.notification.admin.PushAdminDtos.ActionResult;
import edu.bingol.backend.notification.admin.PushAdminDtos.BulkAction;
import edu.bingol.backend.notification.admin.PushAdminDtos.BulkRequest;
import edu.bingol.backend.notification.admin.PushAdminDtos.BulkResult;
import edu.bingol.backend.notification.admin.PushAdminDtos.CampaignFailures;
import edu.bingol.backend.notification.admin.PushAdminDtos.DeviceSummary;
import edu.bingol.backend.notification.admin.PushAdminDtos.NotificationStats;
import edu.bingol.backend.notification.admin.PushAdminDtos.OutboxDetail;
import edu.bingol.backend.notification.admin.PushAdminDtos.OutboxRow;
import jakarta.validation.Valid;
import java.time.LocalDate;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici push altyapisi (P14): kuyruk listesi/ayrinti/yeniden dene/iptal/toplu, cihaz ozeti, kampanya hata gruplari,
 * bildirim kutusu istatistikleri. `/api/admin/**` yalniz ADMIN; yazmalar AuditInterceptor ile denetlenir (hedef PUSH_OUTBOX),
 * hiz siniri ve sebep zorunlulugu AdminGuardInterceptor/AdminGuardPolicy'de. Hicbir yanit yuk ya da ham token icermez.
 * Mevcut `/api/admin/push/fcm/*`, `/outbox/stats`, `/outbox/retry-dead` uclari degismedi. Ayrinti: docs/changes/push.md.
 */
@RestController
@RequestMapping("/api/admin")
public class PushOpsController {

    private final PushOutboxOpsService outbox;
    private final PushOpsReadService reads;

    public PushOpsController(PushOutboxOpsService outbox, PushOpsReadService reads) {
        this.outbox = outbox;
        this.reads = reads;
    }

    @GetMapping("/push/outbox")
    public PageResponse<OutboxRow> list(@RequestParam(required = false) String status,
                                        @RequestParam(required = false) String type,
                                        @RequestParam(required = false) Long campaignId,
                                        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                        @RequestParam(defaultValue = "0") int page,
                                        @RequestParam(defaultValue = "20") int size) {
        return outbox.list(new PushOutboxOpsService.Filter(status, type, campaignId, from, to), page, size);
    }

    @GetMapping("/push/outbox/{id}")
    public OutboxDetail detail(@PathVariable Long id) {
        AuditContext.target("PUSH_OUTBOX", id);
        return outbox.detail(id);
    }

    @PostMapping("/push/outbox/{id}/retry")
    public ActionResult retry(@PathVariable Long id) {
        AuditContext.target("PUSH_OUTBOX", id).summary("push kuyruk kaydi yeniden denemeye alindi");
        return outbox.retry(id);
    }

    @AdminReasonRequired
    @PostMapping("/push/outbox/{id}/cancel")
    public ActionResult cancel(@PathVariable Long id) {
        AuditContext.target("PUSH_OUTBOX", id).summary("push kuyruk kaydi iptal edildi");
        return outbox.cancel(id);
    }

    @AdminReasonRequired
    @PostMapping("/push/outbox/bulk")
    public BulkResult bulk(@Valid @RequestBody BulkRequest body) {
        AuditContext.target("PUSH_OUTBOX", "bulk");
        BulkResult res = outbox.bulk(body.action(), body.ids());
        AuditContext.summary((res.action() == BulkAction.RETRY ? "toplu yeniden deneme: " : "toplu iptal: ")
                + res.succeeded() + "/" + res.requested() + " kayit");
        return res;
    }

    @GetMapping("/push/devices/summary")
    public DeviceSummary devices() {
        return reads.deviceSummary();
    }

    @GetMapping("/push/campaigns/{id}/failures")
    public CampaignFailures failures(@PathVariable Long id) {
        return reads.campaignFailures(id);
    }

    @GetMapping("/notifications/stats")
    public NotificationStats notificationStats(@RequestParam(required = false) Integer days) {
        return reads.notificationStats(days);
    }
}
