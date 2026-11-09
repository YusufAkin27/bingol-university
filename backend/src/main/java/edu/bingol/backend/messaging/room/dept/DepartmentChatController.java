package edu.bingol.backend.messaging.room.dept;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.room.dept.DepartmentChatService.DepartmentChatView;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Bolum sohbet grubu uclari (kullanici). Yalnizca HTTP eslemesi + rate limit; kurallar DepartmentChatService'te. */
@RestController
@RequestMapping("/api/department-chat")
public class DepartmentChatController {

    private final DepartmentChatService chat;
    private final RateLimiter limiter;

    public DepartmentChatController(DepartmentChatService chat, RateLimiter limiter) {
        this.chat = chat;
        this.limiter = limiter;
    }

    /** Profil bolumune gore grup durumu (available=false: bolum yok). */
    @GetMapping
    public DepartmentChatView get() {
        Long me = CurrentUser.id();
        limiter.check("dept-chat-read:user:" + me, 120, Duration.ofMinutes(1));
        return chat.get(me);
    }

    @PostMapping("/join")
    public DepartmentChatView join() {
        Long me = CurrentUser.id();
        limiter.check("dept-chat:user:" + me, 20, Duration.ofMinutes(10));
        return chat.join(me);
    }

    @DeleteMapping("/membership")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave(@RequestParam(required = false) Long conversationId) {
        Long me = CurrentUser.id();
        limiter.check("dept-chat:user:" + me, 20, Duration.ofMinutes(10));
        if (conversationId != null) {
            chat.leaveByConversation(me, conversationId); // v2: istenen kanal (bilgi sayfasindan)
        } else {
            chat.leave(me);
        }
    }
}
