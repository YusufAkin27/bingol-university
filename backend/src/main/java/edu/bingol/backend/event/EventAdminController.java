package edu.bingol.backend.event;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.dto.CommunityDtos.ReviewRequest;
import edu.bingol.backend.event.admission.EventAdmission;
import edu.bingol.backend.event.dto.EventAdminDtos.AdminEventDetail;
import edu.bingol.backend.event.dto.EventAdminDtos.AdminUpdateRequest;
import edu.bingol.backend.event.dto.EventAdminDtos.ReasonRequest;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import jakarta.validation.Valid;
import java.time.Duration;
import java.time.Instant;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici etkinlik moderasyonu (/api/admin/** zaten SecurityConfig'te ROLE_ADMIN ister; yazma islemleri
 * AuditInterceptor ile denetlenir, sebep ayrica event_moderation_log'a yazilir). Ayrinti: docs/ADMIN_API.md.
 */
@RestController
@RequestMapping("/api/admin/events")
public class EventAdminController {

    static final int PER_MINUTE = 60;

    private final EventService events;
    private final EventModerationService moderation;
    private final RateLimiter limiter;

    public EventAdminController(EventService events, EventModerationService moderation, RateLimiter limiter) {
        this.events = events;
        this.moderation = moderation;
        this.limiter = limiter;
    }

    /**
     * Suzmeli liste (id'ye gore azalan, imec = son id). status: PENDING_REVIEW (varsayilan) | ACTIVE | REJECTED |
     * CANCELLED | HIDDEN | ALL. q: baslik/yer/kulup/organizator (Turkce harf duyarsiz). standalone=true: kulupsuz.
     * from/to: baslangic zamani araligi (ISO-8601 anlik, ornek 2026-11-01T00:00:00Z).
     */
    @GetMapping
    public CursorPage<EventView> list(@RequestParam(required = false) String status,
                                      @RequestParam(required = false) String q,
                                      @RequestParam(required = false) Long communityId,
                                      @RequestParam(defaultValue = "false") boolean standalone,
                                      @RequestParam(required = false) EventAdmission.Mode joinPolicy,
                                      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
                                      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
                                      @RequestParam(required = false) Long cursor,
                                      @RequestParam(defaultValue = "20") int size) {
        limit();
        return moderation.list(status, q, communityId, standalone, joinPolicy, from, to, cursor, size);
    }

    @GetMapping("/{id}")
    public AdminEventDetail detail(@PathVariable Long id) {
        limit();
        return moderation.detail(id);
    }

    @PostMapping("/{id}/approve")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void approve(@PathVariable Long id) {
        limit();
        events.review(id, true, null);
    }

    @PostMapping("/{id}/reject")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reject(@PathVariable Long id, @Valid @RequestBody(required = false) ReviewRequest r) {
        limit();
        events.review(id, false, r == null ? null : r.reason());
    }

    /** ACTIVE -> HIDDEN (sessiz, geri alinabilir). */
    @PostMapping("/{id}/hide")
    public AdminEventDetail hide(@PathVariable Long id, @Valid @RequestBody ReasonRequest r) {
        limit();
        return moderation.hide(adminId(), id, r.reason());
    }

    /** HIDDEN -> ACTIVE. */
    @PostMapping("/{id}/unhide")
    public AdminEventDetail unhide(@PathVariable Long id, @Valid @RequestBody ReasonRequest r) {
        limit();
        return moderation.unhide(adminId(), id, r.reason());
    }

    /** ACTIVE | PENDING_REVIEW | HIDDEN -> CANCELLED (katilimcilara ve sahibine bildirim). */
    @PostMapping("/{id}/cancel")
    public AdminEventDetail cancel(@PathVariable Long id, @Valid @RequestBody ReasonRequest r) {
        limit();
        return moderation.cancel(adminId(), id, r.reason());
    }

    /** Yonetici duzenleme (kismi guncelleme); yanit detay. 409 EVENT_NOT_EDITABLE/EVENT_ENDED/CAPACITY_TOO_LOW. */
    @PatchMapping("/{id}")
    public AdminEventDetail edit(@PathVariable Long id, @Valid @RequestBody AdminUpdateRequest r) {
        limit();
        return moderation.edit(adminId(), id, r.toUpdate(), r.reason());
    }

    /** Yonetici silme = yumusak silme (CANCELLED) + katilimci bildirimi + sohbet kapanisi; sebep sorgu parametresi, zorunlu. */
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id, @RequestParam(required = false) String reason) {
        limit();
        moderation.delete(adminId(), id, reason);
    }

    private void limit() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        limiter.check("adminevents:" + (a == null ? "anon" : a.getName()), PER_MINUTE, Duration.ofMinutes(1));
    }

    /** JWT yoneticisinin id'si; Basic auth yoneticisinde kullanici kaydi yoktur (null). */
    private static Long adminId() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof Long id ? id : null;
    }
}
