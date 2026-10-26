package edu.bingol.backend.community.extras;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/** GET /api/communities/{id}/chat: kulup sohbetini getir-ya-da-olustur (mobil sohbet sekmesi). */
@RestController
public class ClubChatController {

    private final ClubChatService chat;
    private final RateLimiter limiter;

    public ClubChatController(ClubChatService chat, RateLimiter limiter) {
        this.chat = chat;
        this.limiter = limiter;
    }

    @GetMapping("/api/communities/{id}/chat")
    public ConversationView chat(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("community-chat:user:" + a.id(), 120, Duration.ofHours(1));
        return chat.open(a, id);
    }
}
