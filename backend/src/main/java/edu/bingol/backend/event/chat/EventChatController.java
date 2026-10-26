package edu.bingol.backend.event.chat;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.chat.EventChatService.EventChatView;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** T25 etkinlik sohbet odasi uclari. Yalnizca HTTP eslemesi ve rate limit; kurallar EventChatService'te. */
@RestController
@RequestMapping("/api/events/{id}/chat-room")
public class EventChatController {

    public record ClosedRequest(@NotNull Boolean closed) {}

    private final EventChatService chat;
    private final RateLimiter limiter;

    public EventChatController(EventChatService chat, RateLimiter limiter) {
        this.chat = chat;
        this.limiter = limiter;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public EventChatView open(@PathVariable Long id) {
        Actor a = limit();
        return chat.open(a, id);
    }

    @GetMapping
    public EventChatView get(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("event-chat-read:user:" + a.id(), 120, Duration.ofMinutes(1));
        return chat.get(a, id);
    }

    @PutMapping("/closed")
    public EventChatView closed(@PathVariable Long id, @Valid @RequestBody ClosedRequest r) {
        Actor a = limit();
        return chat.setClosed(a, id, r.closed());
    }

    @PostMapping("/join")
    public EventChatView join(@PathVariable Long id) {
        Actor a = limit();
        return chat.join(a, id);
    }

    @DeleteMapping("/membership")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void leave(@PathVariable Long id) {
        Actor a = limit();
        chat.leave(a, id);
    }

    private Actor limit() {
        Actor a = Actor.current();
        limiter.check("event-chat:user:" + a.id(), 30, Duration.ofMinutes(10));
        return a;
    }
}
