package edu.bingol.backend.academic;

import edu.bingol.backend.academic.AcademicDtos.AcademicEventRequest;
import edu.bingol.backend.academic.AcademicDtos.AcademicEventView;
import edu.bingol.backend.academic.AcademicDtos.AdminAcademicEventView;
import edu.bingol.backend.academic.AcademicDtos.CalendarView;
import edu.bingol.backend.academic.AcademicDtos.EventImportRequest;
import edu.bingol.backend.academic.AcademicDtos.EventImportResult;
import edu.bingol.backend.academic.AcademicDtos.Page;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import java.util.List;
import java.util.Map;
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

/** Akademik takvim: kullanici ve yonetici uclari (yalniz HTTP eslemesi + hiz siniri). */
@RestController
@RequestMapping("/api")
public class AcademicController {

    private final AcademicCalendarService calendar;
    private final RateLimiter limiter;

    public AcademicController(AcademicCalendarService calendar, RateLimiter limiter) {
        this.calendar = calendar;
        this.limiter = limiter;
    }

    private Long read() {
        Long uid = CurrentUser.id();
        limiter.check("acd:read:" + uid, 120, Duration.ofMinutes(1));
        return uid;
    }

    /** Yonetici kimligi (Basic auth yoneticisinde kullanici kaydi yoktur: null). Yazma hiz siniri 120/dk. */
    private Long admin() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        Long id = a != null && a.getPrincipal() instanceof Long l ? l : null;
        limiter.check("acd:admin:" + (id != null ? id : "basic"), 120, Duration.ofMinutes(1));
        return id;
    }

    // ---- akademik takvim (kullanici) ----

    @GetMapping("/academic/calendar")
    public CalendarView calendar(@RequestParam(required = false) String month, @RequestParam(required = false) String from,
                                 @RequestParam(required = false) String to) {
        return calendar.calendar(read(), month, from, to);
    }

    @GetMapping("/academic/calendar/next")
    public Map<String, List<AcademicEventView>> next(@RequestParam(defaultValue = "5") int limit) {
        return Map.of("items", calendar.next(read(), limit));
    }

    // ---- yonetici: akademik takvim ----

    @GetMapping("/admin/academic/events")
    public Page<AdminAcademicEventView> adminEvents(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size,
                                                    @RequestParam(required = false) String kind, @RequestParam(required = false) String q,
                                                    @RequestParam(required = false) Boolean published) {
        return calendar.adminList(page, size, kind, q, published);
    }

    @PostMapping("/admin/academic/events")
    @ResponseStatus(HttpStatus.CREATED)
    public AdminAcademicEventView adminCreateEvent(@RequestBody AcademicEventRequest req) {
        return calendar.create(admin(), req);
    }

    @PostMapping("/admin/academic/events/import")
    public EventImportResult adminImportEvents(@RequestBody EventImportRequest req) {
        return calendar.importText(admin(), req.text(), Boolean.TRUE.equals(req.publish()));
    }

    @GetMapping("/admin/academic/events/{id}")
    public AdminAcademicEventView adminEvent(@PathVariable Long id) {
        return calendar.adminGet(id);
    }

    @PatchMapping("/admin/academic/events/{id}")
    public AdminAcademicEventView adminUpdateEvent(@PathVariable Long id, @RequestBody AcademicEventRequest req) {
        return calendar.update(admin(), id, req);
    }

    @DeleteMapping("/admin/academic/events/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void adminDeleteEvent(@PathVariable Long id) {
        admin();
        calendar.delete(id);
    }

    @PostMapping("/admin/academic/events/{id}/publish")
    public AdminAcademicEventView adminPublishEvent(@PathVariable Long id) {
        admin();
        return calendar.setPublished(id, true);
    }

    @PostMapping("/admin/academic/events/{id}/unpublish")
    public AdminAcademicEventView adminUnpublishEvent(@PathVariable Long id) {
        admin();
        return calendar.setPublished(id, false);
    }
}
