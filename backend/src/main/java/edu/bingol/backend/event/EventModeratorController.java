package edu.bingol.backend.event;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.EventModeratorService.ModeratorView;
import edu.bingol.backend.event.EventModeratorService.MyPermissions;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Etkinlik moderatorleri + yoklama acma anahtari. Yazma uclari yalniz sahibe aittir. */
@RestController
@RequestMapping("/api")
public class EventModeratorController {

    public record PermissionsRequest(List<String> permissions) {
    }

    public record OpenRequest(boolean open) {
    }

    private final EventModeratorService svc;
    private final RateLimiter limiter;

    public EventModeratorController(EventModeratorService svc, RateLimiter limiter) {
        this.svc = svc;
        this.limiter = limiter;
    }

    @GetMapping("/events/{id}/my-permissions")
    public MyPermissions me(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("event-perms:user:" + a.id(), 120, Duration.ofMinutes(1));
        return svc.me(a, id);
    }

    @GetMapping("/events/{id}/moderators")
    public List<ModeratorView> list(@PathVariable Long id) {
        return svc.list(Actor.current(), id);
    }

    @PutMapping("/events/{id}/moderators/{userId}")
    public ModeratorView put(@PathVariable Long id, @PathVariable Long userId, @RequestBody PermissionsRequest r) {
        Actor a = Actor.current();
        limiter.check("event-moderator:user:" + a.id(), 60, Duration.ofHours(1));
        return svc.put(a, id, userId, r.permissions());
    }

    @DeleteMapping("/events/{id}/moderators/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remove(@PathVariable Long id, @PathVariable Long userId) {
        Actor a = Actor.current();
        limiter.check("event-moderator:user:" + a.id(), 60, Duration.ofHours(1));
        svc.remove(a, id, userId);
    }

    @PutMapping("/events/{id}/attendance-open")
    public MyPermissions attendanceOpen(@PathVariable Long id, @RequestBody OpenRequest r) {
        Actor a = Actor.current();
        limiter.check("event-attopen:user:" + a.id(), 60, Duration.ofHours(1));
        return svc.setAttendanceOpen(a, id, r.open());
    }
}
