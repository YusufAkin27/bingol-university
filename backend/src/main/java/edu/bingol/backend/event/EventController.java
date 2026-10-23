package edu.bingol.backend.event;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.dto.EventDtos.AttendanceRow;
import edu.bingol.backend.event.dto.EventDtos.AttendeeView;
import edu.bingol.backend.event.dto.EventDtos.BulkRequest;
import edu.bingol.backend.event.dto.EventDtos.BulkResult;
import edu.bingol.backend.event.dto.EventDtos.CalendarItem;
import edu.bingol.backend.event.dto.EventDtos.CheckinCode;
import edu.bingol.backend.event.dto.EventDtos.CheckinRequest;
import edu.bingol.backend.event.dto.EventDtos.CreateEventRequest;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import edu.bingol.backend.event.dto.EventDtos.MarkRequest;
import edu.bingol.backend.event.dto.EventDtos.MyAttendance;
import edu.bingol.backend.event.dto.EventDtos.RsvpRequest;
import edu.bingol.backend.event.dto.EventDtos.RsvpResult;
import edu.bingol.backend.event.dto.EventDtos.UpdateEventRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.time.Instant;
import java.time.YearMonth;
import java.util.List;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** Etkinlik uclari. Yalnizca HTTP eslemesi ve rate limit; kurallar EventService / AttendanceService'te. */
@RestController
@RequestMapping("/api")
public class EventController {

    private final EventService events;
    private final AttendanceService attendance;
    private final RateLimiter limiter;

    public EventController(EventService events, AttendanceService attendance, RateLimiter limiter) {
        this.events = events;
        this.attendance = attendance;
        this.limiter = limiter;
    }

    /** Yayindaysa 201, admin onayi bekliyorsa 202. */
    @PostMapping("/events")
    public ResponseEntity<EventView> create(@Valid @RequestBody CreateEventRequest r) {
        Actor a = Actor.current();
        limiter.check("event-create:user:" + a.id(), 10, Duration.ofHours(1));
        EventView v = events.create(a, r);
        return ResponseEntity.status(v.status() == UserEvent.Status.ACTIVE ? HttpStatus.CREATED : HttpStatus.ACCEPTED).body(v);
    }

    /** from/to ISO-8601 zaman (ornek 2026-11-01T00:00:00Z); from verilmezse simdiden itibaren. */
    @GetMapping("/events")
    public CursorPage<EventView> list(@RequestParam(required = false) Instant from,
                                      @RequestParam(required = false) Instant to,
                                      @RequestParam(required = false) Long communityId,
                                      @RequestParam(required = false) Long cursor,
                                      @RequestParam(defaultValue = "20") int size) {
        return events.list(Actor.current(), from, to, communityId, cursor, size);
    }

    /** Aylik birlesik takvim: kullanici etkinlikleri (USER) + resmi site etkinlikleri (OFFICIAL). month=YYYY-MM */
    @GetMapping("/events/calendar")
    public List<CalendarItem> calendar(@RequestParam YearMonth month) {
        return events.calendar(Actor.current(), month);
    }

    @GetMapping("/events/{id}")
    public EventView get(@PathVariable Long id) {
        return events.get(Actor.current(), id);
    }

    @PatchMapping("/events/{id}")
    public EventView update(@PathVariable Long id, @Valid @RequestBody UpdateEventRequest r) {
        return events.update(Actor.current(), id, r);
    }

    @DeleteMapping("/events/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        events.delete(Actor.current(), id);
    }

    /** multipart alani "file", jpg/png/webp, en fazla 3 MB. */
    @PostMapping("/events/{id}/cover")
    public EventView cover(@PathVariable Long id, @RequestParam("file") MultipartFile file) {
        Actor a = Actor.current();
        limiter.check("event-cover:user:" + a.id(), 10, Duration.ofHours(1));
        return events.setCover(a, id, file);
    }

    @PutMapping("/events/{id}/rsvp")
    public RsvpResult rsvp(@PathVariable Long id, @Valid @RequestBody RsvpRequest r) {
        Actor a = Actor.current();
        limiter.check("event-rsvp:user:" + a.id(), 30, Duration.ofMinutes(1));
        return events.rsvp(a, id, r.status());
    }

    @DeleteMapping("/events/{id}/rsvp")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancelRsvp(@PathVariable Long id) {
        events.cancelRsvp(Actor.current(), id);
    }

    /** Organizatore: katilimcilar (varsayilan GOING; status=INTERESTED da istenebilir). */
    @GetMapping("/events/{id}/attendees")
    public CursorPage<AttendeeView> attendees(@PathVariable Long id,
                                              @RequestParam(required = false) EventRsvp.Status status,
                                              @RequestParam(required = false) Long cursor,
                                              @RequestParam(defaultValue = "50") int size) {
        return events.attendees(Actor.current(), id, status, cursor, size);
    }

    @GetMapping("/me/events")
    public CursorPage<EventView> mine(@RequestParam(defaultValue = "attending") String mode,
                                      @RequestParam(required = false) Long cursor,
                                      @RequestParam(defaultValue = "20") int size) {
        return events.mine(Actor.current(), mode, cursor, size);
    }

    // ---- yoklama ----

    /** Organizator: 30-60 sn gecerli QR yuku. Istemci her ~25 sn'de yeniler. */
    @GetMapping("/events/{id}/checkin-code")
    public CheckinCode checkinCode(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("checkin-code:user:" + a.id(), 60, Duration.ofMinutes(1));
        return attendance.issueCode(a, id, Instant.now());
    }

    @PostMapping("/events/{id}/check-in")
    public MyAttendance checkIn(@PathVariable Long id, @Valid @RequestBody CheckinRequest r) {
        Actor a = Actor.current();
        // Kod tahmini/kaba kuvvet denemelerine karsi siki limit
        limiter.check("checkin:user:" + a.id(), 20, Duration.ofMinutes(1));
        return attendance.checkIn(a, id, r.code(), Instant.now());
    }

    @GetMapping("/events/{id}/my-attendance")
    public MyAttendance myAttendance(@PathVariable Long id) {
        return attendance.mine(Actor.current(), id, Instant.now());
    }

    @GetMapping("/events/{id}/attendance")
    public List<AttendanceRow> attendanceList(@PathVariable Long id) {
        return attendance.list(Actor.current(), id);
    }

    @PutMapping("/events/{id}/attendance/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void mark(@PathVariable Long id, @PathVariable Long userId, @Valid @RequestBody MarkRequest r) {
        Actor a = Actor.current();
        limiter.check("attendance-mark:user:" + a.id(), 120, Duration.ofMinutes(1));
        attendance.mark(a, id, userId, r.present(), Instant.now());
    }

    @PostMapping("/events/{id}/attendance/bulk")
    public BulkResult bulk(@PathVariable Long id, @Valid @RequestBody BulkRequest r) {
        Actor a = Actor.current();
        limiter.check("attendance-bulk:user:" + a.id(), 20, Duration.ofMinutes(1));
        return attendance.bulk(a, id, r.entries(), Instant.now());
    }

    @GetMapping("/events/{id}/attendance.csv")
    public ResponseEntity<String> attendanceCsv(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("attendance-csv:user:" + a.id(), 10, Duration.ofMinutes(1));
        String body = attendance.csv(a, id);
        return ResponseEntity.ok()
                .contentType(new MediaType("text", "csv", java.nio.charset.StandardCharsets.UTF_8))
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename("event-" + id + "-attendance.csv").build().toString())
                .body(body);
    }
}
