package edu.bingol.backend.admin.chat;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici sohbet goruntuleyici (`/api/admin/**` yalnizca ADMIN; kimlik JWT'den, Basic auth kabul edilmez).
 * Her sayfa istegi otomatik denetim kaydi uretir; hiz siniri yonetici basina dakikada 120 sayfa.
 */
@edu.bingol.backend.admin.AuditRead
@RestController
@RequestMapping("/api/admin/users/{userId}/conversations")
public class AdminChatViewerController {

    static final int PAGES_PER_MINUTE = 120;

    private final AdminChatViewerService service;
    private final RateLimiter limiter;

    public AdminChatViewerController(AdminChatViewerService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /** GET /api/admin/users/{id}/conversations?cursor&size: konusma listesi (son mesaj en yeni once). */
    @GetMapping
    public AdminChatViewerService.ConversationPage conversations(@PathVariable long userId,
            @RequestParam(required = false) Long cursor, @RequestParam(defaultValue = "20") int size,
            HttpServletRequest http) {
        long adminId = CurrentUser.id();
        limiter.check("adminchat:" + adminId, PAGES_PER_MINUTE, Duration.ofMinutes(1));
        return service.conversations(adminId, userId, cursor, size, http.getRemoteAddr());
    }

    /** GET /api/admin/users/{id}/conversations/{cid}/messages?before&size: eskiden yeniye sirali; nextBefore imleci. */
    @GetMapping("/{conversationId}/messages")
    public AdminChatViewerService.MessagePage messages(@PathVariable long userId, @PathVariable long conversationId,
            @RequestParam(required = false) Long before, @RequestParam(defaultValue = "50") int size,
            HttpServletRequest http) {
        long adminId = CurrentUser.id();
        limiter.check("adminchat:" + adminId, PAGES_PER_MINUTE, Duration.ofMinutes(1));
        return service.messages(adminId, userId, conversationId, before, size, http.getRemoteAddr());
    }
}
