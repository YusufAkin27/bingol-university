package edu.bingol.backend.admin.chat;

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

    public AdminChatFeedController(AdminChatFeedService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /** GET /api/admin/chat-media: tum sohbet ekleri (imlec = ek id, size <= 60). */
    @GetMapping("/chat-media")
    public AdminChatFeedService.MediaPage media(@RequestParam(required = false) Long cursor,
            @RequestParam(defaultValue = "30") int size, @RequestParam(required = false) String kind,
            @RequestParam(required = false) Boolean viewOnce, @RequestParam(required = false) Boolean deleted,
            @RequestParam(required = false) Long userId, @RequestParam(required = false) Long conversationId,
            @RequestParam(required = false) String from, @RequestParam(required = false) String to,
            @RequestParam(defaultValue = "desc") String order, HttpServletRequest http) {
        long adminId = CurrentUser.id();
        limit(adminId);
        return service.media(adminId, cursor, size, kind, viewOnce, deleted, userId, conversationId, from, to, order,
                http.getRemoteAddr());
    }

    /** GET /api/admin/chat-media/stats: ek sayilari. */
    @GetMapping("/chat-media/stats")
    public AdminChatFeedService.Stats stats(HttpServletRequest http) {
        long adminId = CurrentUser.id();
        limit(adminId);
        return service.stats(adminId, http.getRemoteAddr());
    }

    /** GET /api/admin/chat-messages: tum sohbetlerden mesaj akisi (en yeni once, imlec = mesaj id, size <= 50). */
    @GetMapping("/chat-messages")
    public AdminChatFeedService.FeedPage messages(@RequestParam(required = false) Long cursor,
            @RequestParam(defaultValue = "30") int size, @RequestParam(required = false) Long userId,
            @RequestParam(required = false) Long senderId, @RequestParam(required = false) Long conversationId,
            @RequestParam(required = false) Boolean deleted, @RequestParam(required = false) Boolean suppressed,
            @RequestParam(required = false) Boolean hasMedia, @RequestParam(required = false) String from,
            @RequestParam(required = false) String to, HttpServletRequest http) {
        long adminId = CurrentUser.id();
        limit(adminId);
        return service.messages(adminId, cursor, size, userId, senderId, conversationId, deleted, suppressed, hasMedia,
                from, to, http.getRemoteAddr());
    }

    private void limit(long adminId) {
        limiter.check("adminchat:" + adminId, AdminChatViewerController.PAGES_PER_MINUTE, Duration.ofMinutes(1));
    }
}
