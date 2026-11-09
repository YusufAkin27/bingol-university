package edu.bingol.backend.admin.chat;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici toplu izleme alani (`/api/admin/**` yalnizca ADMIN; kimlik JWT'den). Tum sohbetlerdeki ek ve mesaj akisi;
 * her sayfa denetim kaydi uretir; hiz siniri yonetici basina dakikada 120 istek (kullanici goruntuleyiciyle ortak).
 */
@RestController
@RequestMapping("/api/admin")
public class AdminChatFeedController {

    private final AdminChatFeedService service;
    private final RateLimiter limiter;
    private final ClientIp clientIp;

    /** IP: guvenilir proxy zincirinden cozulen gercek istemci (message_access_audit.ip KVKK kaniti; FIX-P09 A08#7). */
    public AdminChatFeedController(AdminChatFeedService service, RateLimiter limiter, ClientIp clientIp) {
        this.service = service;
        this.limiter = limiter;
        this.clientIp = clientIp;
    }

    /** GET /api/admin/chat-media: tum sohbet ekleri (imlec = ek id, size <= 60). */
    @edu.bingol.backend.admin.AuditRead
    @GetMapping("/chat-media")
    public AdminChatFeedService.MediaPage media(@RequestParam(required = false) Long cursor,
            @RequestParam(defaultValue = "30") int size, @RequestParam(required = false) String kind,
            @RequestParam(required = false) Boolean viewOnce, @RequestParam(required = false) Boolean deleted,
            @RequestParam(required = false) Long userId, @RequestParam(required = false) Long conversationId,
            @RequestParam(required = false) String from, @RequestParam(required = false) String to,
            @RequestParam(defaultValue = "desc") String order, @RequestParam(required = false) String scope,
            HttpServletRequest http) {
        long adminId = CurrentUser.id();
        if (isAll(scope, userId, null, conversationId)) {
            limitAll(adminId);
            return service.mediaAll(adminId, cursor, size, kind, viewOnce, deleted, from, to, order, clientIp.of(http));
        }
        AdminChatFeedService.requireScope(userId, null, conversationId);
        limit(adminId);
        return service.media(adminId, cursor, size, kind, viewOnce, deleted, userId, conversationId, from, to, order,
                clientIp.of(http));
    }

    /** GET /api/admin/chat-media/stats: ek sayilari. */
    @GetMapping("/chat-media/stats")
    public AdminChatFeedService.Stats stats(HttpServletRequest http) {
        long adminId = CurrentUser.id();
        limit(adminId);
        return service.stats(adminId, clientIp.of(http));
    }

    /** GET /api/admin/chat-messages: tum sohbetlerden mesaj akisi (en yeni once, imlec = mesaj id, size <= 50). */
    @edu.bingol.backend.admin.AuditRead
    @GetMapping("/chat-messages")
    public AdminChatFeedService.FeedPage messages(@RequestParam(required = false) Long cursor,
            @RequestParam(defaultValue = "30") int size, @RequestParam(required = false) Long userId,
            @RequestParam(required = false) Long senderId, @RequestParam(required = false) Long conversationId,
            @RequestParam(required = false) Boolean deleted, @RequestParam(required = false) Boolean suppressed,
            @RequestParam(required = false) Boolean hasMedia, @RequestParam(required = false) String from,
            @RequestParam(required = false) String to, @RequestParam(required = false) String scope,
            HttpServletRequest http) {
        long adminId = CurrentUser.id();
        if (isAll(scope, userId, senderId, conversationId)) {
            limitAll(adminId);
            return service.messagesAll(adminId, cursor, size, deleted, suppressed, hasMedia, from, to, clientIp.of(http));
        }
        AdminChatFeedService.requireScope(userId, senderId, conversationId);
        limit(adminId);
        return service.messages(adminId, cursor, size, userId, senderId, conversationId, deleted, suppressed, hasMedia,
                from, to, clientIp.of(http));
    }

    /** "Tum sohbetler" sayfa hizi (yonetici basina dakikada); genel sinirdan siki. */
    public static final int ALL_PAGES_PER_MINUTE = 20;

    /**
     * scope = ALL ise (kullanici/gonderen/sohbet suzgeciyle birlikte verilemez: 400 INVALID_FILTER) true; ayrica
     * chat.read.all izni ister (yoksa 403 ADMIN_PERMISSION_DENIED). Baglam yoksa (interceptor calismadi) ret: fail-closed.
     */
    static boolean isAll(String scope, Long userId, Long senderId, Long conversationId) {
        String sc = scope == null ? "" : scope.trim().toUpperCase(java.util.Locale.ROOT);
        if (sc.isEmpty() || "USER".equals(sc) || "CONVERSATION".equals(sc)) {
            return false;
        }
        if (!"ALL".equals(sc) || userId != null || senderId != null || conversationId != null) {
            throw new edu.bingol.backend.common.ApiException(org.springframework.http.HttpStatus.BAD_REQUEST,
                    "INVALID_FILTER", "Geçersiz süzgeç değeri.");
        }
        var ctx = edu.bingol.backend.admin.rbac.AdminPermissionContext.current();
        if (ctx == null || !ctx.can(edu.bingol.backend.admin.rbac.PermissionMatrix.CHAT_READ_ALL)) {
            throw new edu.bingol.backend.common.ApiException(org.springframework.http.HttpStatus.FORBIDDEN,
                    "ADMIN_PERMISSION_DENIED", "Bu işlem için yetkiniz yok (gereken izin: "
                            + edu.bingol.backend.admin.rbac.PermissionMatrix.CHAT_READ_ALL + ").",
                    edu.bingol.backend.admin.rbac.PermissionMatrix.CHAT_READ_ALL);
        }
        return true;
    }

    private void limitAll(long adminId) {
        limiter.check("adminchatall:" + adminId, ALL_PAGES_PER_MINUTE, Duration.ofMinutes(1));
    }

    private void limit(long adminId) {
        limiter.check("adminchat:" + adminId, AdminChatViewerController.PAGES_PER_MINUTE, Duration.ofMinutes(1));
    }
}
