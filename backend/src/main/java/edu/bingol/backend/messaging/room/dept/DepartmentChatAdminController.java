package edu.bingol.backend.messaging.room.dept;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.room.dept.DepartmentChatService.AdminRoomView;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Yonetici: bolum gruplarini listele, kapat/ac. Izin: chat.read / chat.write (AdminPermissionPolicy). */
@RestController
@RequestMapping("/api/admin/department-chats")
public class DepartmentChatAdminController {

    public record ClosedRequest(@NotNull Boolean closed) {}

    private final DepartmentChatService chat;
    private final RateLimiter limiter;

    public DepartmentChatAdminController(DepartmentChatService chat, RateLimiter limiter) {
        this.chat = chat;
        this.limiter = limiter;
    }

    @GetMapping
    public List<AdminRoomView> list() {
        return chat.adminList();
    }

    @PutMapping("/{id}/closed")
    public AdminRoomView closed(@PathVariable Long id, @Valid @RequestBody ClosedRequest r) {
        limiter.check("admin-dept-chat:global", 60, Duration.ofMinutes(10));
        return chat.adminSetClosed(id, r.closed());
    }
}
