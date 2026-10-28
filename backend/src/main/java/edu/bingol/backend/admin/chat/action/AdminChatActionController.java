package edu.bingol.backend.admin.chat.action;

import edu.bingol.backend.admin.AdminReasonRequired;
import edu.bingol.backend.admin.AuditContext;
import edu.bingol.backend.admin.AuditRead;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.BulkHideRequest;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.BulkResult;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.ConversationExport;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.ConversationMeta;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.ConversationStateResult;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.CsvExport;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.MemberRemoval;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.MessageActionResult;
import edu.bingol.backend.admin.chat.action.ChatActionDtos.ReasonBody;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici sohbet mudahalesi (P08): mesaj gizle/geri goster/kalici sil/toplu gizle, sohbet kapat/ac, uye cikar, ust veri,
 * yasal disa aktarma. `/api/admin/**` yalniz ADMIN; kimlik JWT'den (Basic auth kabul edilmez: 401). Yazmalar AuditInterceptor
 * ile denetlenir (hedef MESSAGE|CONVERSATION); hiz siniri ve yikici sinir AdminGuardInterceptor/AdminGuardPolicy'de;
 * sebep zorunlulugu {@link AdminReasonRequired} + politika. Sebep: `X-Admin-Reason` basligi ya da govdede `reason`.
 * Ayrinti: docs/ADMIN_API.md "Sohbet mudahalesi (P08)".
 */
@RestController
@RequestMapping("/api/admin")
public class AdminChatActionController {

    static final int READ_PER_MINUTE = 120;
    static final int EXPORT_PER_HOUR = 10;
    public static final String CONFIRM_HEADER = "X-Admin-Confirm";

    private final AdminChatMessageActionService messages;
    private final AdminConversationActionService conversations;
    private final AdminConversationExportService export;
    private final ChatActionAuditWriter auditWriter;
    private final RateLimiter limiter;
    private final ClientIp clientIp;

    public AdminChatActionController(AdminChatMessageActionService messages, AdminConversationActionService conversations,
                                     AdminConversationExportService export, ChatActionAuditWriter auditWriter,
                                     RateLimiter limiter, ClientIp clientIp) {
        this.messages = messages;
        this.conversations = conversations;
        this.export = export;
        this.auditWriter = auditWriter;
        this.limiter = limiter;
        this.clientIp = clientIp;
    }

    // ---- mesaj ----

    @AdminReasonRequired
    @PostMapping("/messages/{id}/hide")
    public MessageActionResult hide(@PathVariable Long id, @Valid @RequestBody(required = false) ReasonBody body) {
        String reason = reason(body);
        AuditContext.target("MESSAGE", id).reason(reason).summary("mesaj yonetici tarafindan gizlendi");
        return messages.hide(CurrentUser.id(), id, reason);
    }

    @AdminReasonRequired
    @PostMapping("/messages/{id}/unhide")
    public MessageActionResult unhide(@PathVariable Long id, @Valid @RequestBody(required = false) ReasonBody body) {
        String reason = reason(body);
        AuditContext.target("MESSAGE", id).reason(reason).summary("yonetici gizlemesi geri alindi");
        return messages.unhide(CurrentUser.id(), id, reason);
    }

    /** Kalici silme: icerik temizlenir, yer tutucu kalir; GERI ALINAMAZ. Sebep en az 10 karakter. */
    @AdminReasonRequired(min = 10)
    @DeleteMapping("/messages/{id}")
    public MessageActionResult purge(@PathVariable Long id, @Valid @RequestBody(required = false) ReasonBody body) {
        String reason = reason(body);
        AuditContext.target("MESSAGE", id).reason(reason).summary("mesaj KALICI silindi (geri alinamaz)");
        return messages.purge(CurrentUser.id(), id, reason);
    }

    @AdminReasonRequired
    @PostMapping("/messages/bulk-hide")
    public BulkResult bulkHide(@Valid @RequestBody BulkHideRequest body, HttpServletRequest http) {
        String reason = body.reason() != null && !body.reason().isBlank() ? body.reason().strip()
                : AuditContext.currentReason();
        AuditContext.reason(reason).summary("toplu gizleme: " + (body.ids() == null ? 0 : body.ids().size()) + " mesaj");
        var auth = SecurityContextHolder.getContext().getAuthentication();
        return messages.bulkHide(CurrentUser.id(), body.ids(), reason,
                (r, items) -> auditWriter.bulkHide(http, auth, r, items));
    }

    // ---- sohbet ----

    @AdminReasonRequired
    @PostMapping("/conversations/{id}/close")
    public ConversationStateResult close(@PathVariable Long id, @Valid @RequestBody(required = false) ReasonBody body) {
        String reason = reason(body);
        AuditContext.target("CONVERSATION", id).reason(reason).summary("sohbet yonetici tarafindan kapatildi");
        return conversations.close(CurrentUser.id(), id, reason);
    }

    @AdminReasonRequired
    @PostMapping("/conversations/{id}/reopen")
    public ConversationStateResult reopen(@PathVariable Long id, @Valid @RequestBody(required = false) ReasonBody body) {
        String reason = reason(body);
        AuditContext.target("CONVERSATION", id).reason(reason).summary("sohbet yeniden acildi");
        return conversations.reopen(CurrentUser.id(), id, reason);
    }

    @AdminReasonRequired
    @DeleteMapping("/conversations/{id}/members/{userId}")
    public MemberRemoval removeMember(@PathVariable Long id, @PathVariable Long userId,
                                      @Valid @RequestBody(required = false) ReasonBody body) {
        String reason = reason(body);
        AuditContext.target("CONVERSATION", id).reason(reason).summary("uye gruptan cikarildi: kullanici " + userId);
        return conversations.removeMember(CurrentUser.id(), id, userId, reason);
    }

    /** Ust veri (ICERIK YOK): tur, uyeler (e-posta maskeli), mesaj sayisi, durum, acik rapor sayisi. */
    @AuditRead
    @GetMapping("/conversations/{id}")
    public ConversationMeta meta(@PathVariable Long id) {
        limiter.check("adminchat:" + CurrentUser.id(), READ_PER_MINUTE, Duration.ofMinutes(1));
        AuditContext.target("CONVERSATION", id);
        return conversations.meta(id);
    }

    /**
     * Yasal talep icin icerik disa aktarimi. Sebep >= 20 karakter (baslik `X-Admin-Reason` onerilir) ve ikinci onay
     * basligi `X-Admin-Confirm: <sohbet id>` zorunlu; hem admin_audit hem message_access_audit'e yazilir.
     * format=json (varsayilan) | csv; en cok 5000 mesaj, fazlasi icin `afterId`.
     */
    @AuditRead
    @AdminReasonRequired(min = AdminConversationExportService.MIN_REASON)
    @GetMapping("/conversations/{id}/export")
    public ResponseEntity<?> exportConversation(@PathVariable Long id, @RequestParam(defaultValue = "json") String format,
                                                @RequestParam(required = false) Long afterId,
                                                @RequestHeader(value = CONFIRM_HEADER, required = false) String confirm,
                                                HttpServletRequest http) {
        long adminId = CurrentUser.id();
        limiter.check("adminexport:" + adminId, EXPORT_PER_HOUR, Duration.ofHours(1));
        boolean csv = "csv".equalsIgnoreCase(format);
        if (!csv && !"json".equalsIgnoreCase(format)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek.");
        }
        String reason = AuditContext.currentReason();
        AuditContext.target("CONVERSATION", id);
        String ip = clientIp.of(http);
        ResponseEntity.BodyBuilder ok = ResponseEntity.ok().cacheControl(CacheControl.noStore());
        if (csv) {
            CsvExport out = export.exportCsv(adminId, id, reason, confirm, afterId, ip);
            AuditContext.summary("yasal disa aktarma (csv): " + out.messageCount() + " mesaj");
            return withContinuation(ok, out.truncated(), out.nextAfterId())
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"conversation-" + id + ".csv\"")
                    .contentType(new MediaType("text", "csv", StandardCharsets.UTF_8)).body(out.body());
        }
        ConversationExport out = export.exportJson(adminId, id, reason, confirm, afterId, ip);
        AuditContext.summary("yasal disa aktarma (json): " + out.messageCount() + " mesaj");
        return withContinuation(ok, out.truncated(), out.nextAfterId()).contentType(MediaType.APPLICATION_JSON).body(out);
    }

    private static ResponseEntity.BodyBuilder withContinuation(ResponseEntity.BodyBuilder b, boolean truncated, Long next) {
        b.header("X-Truncated", String.valueOf(truncated));
        if (next != null) {
            b.header("X-Next-Cursor", String.valueOf(next));
        }
        return b;
    }

    /** Govdedeki sebep, yoksa filtrenin baslik/govdeden ayikladigi sebep. */
    private static String reason(ReasonBody body) {
        return body != null && body.reason() != null && !body.reason().isBlank() ? body.reason().strip()
                : AuditContext.currentReason();
    }
}
