package edu.bingol.backend.event;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.community.dto.CommunityDtos.ReviewRequest;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Bagimsiz etkinlik onay uclari (/api/admin/** zaten SecurityConfig'te ROLE_ADMIN ister). */
@RestController
@RequestMapping("/api/admin/events")
public class EventAdminController {

    private final EventService events;

    public EventAdminController(EventService events) {
        this.events = events;
    }

    /** Varsayilan: onay bekleyenler (id'ye gore azalan). */
    @GetMapping
    public CursorPage<EventView> list(@RequestParam(defaultValue = "PENDING_REVIEW") UserEvent.Status status,
                                      @RequestParam(required = false) Long cursor,
                                      @RequestParam(defaultValue = "20") int size) {
        return events.byStatus(status, cursor, size);
    }

    @PostMapping("/{id}/approve")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void approve(@PathVariable Long id) {
        events.review(id, true, null);
    }

    @PostMapping("/{id}/reject")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reject(@PathVariable Long id, @Valid @RequestBody(required = false) ReviewRequest r) {
        events.review(id, false, r == null ? null : r.reason());
    }
}
