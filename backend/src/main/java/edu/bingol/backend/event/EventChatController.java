package edu.bingol.backend.event;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/** GET /api/events/{id}/chat: etkinlik sohbetini getir-ya-da-olustur (mobil sohbet sekmesi). */
@RestController
public class EventChatController {

    private final EventChatService chat;
    private final RateLimiter limiter;

    public EventChatController(EventChatService chat, RateLimiter limiter) {
        this.chat = chat;
        this.limiter = limiter;
    }

    @GetMapping("/api/events/{id}/chat")
    public ConversationView chat(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("event-chat:user:" + a.id(), 120, Duration.ofHours(1));
        return chat.open(a, id);
    }
}
