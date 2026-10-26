package edu.bingol.backend.event.extras;

import edu.bingol.backend.common.ClientIp;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.extras.ExtrasDtos.AddCoOrganizerRequest;
import edu.bingol.backend.event.extras.ExtrasDtos.AnnouncementRequest;
import edu.bingol.backend.event.extras.ExtrasDtos.AnnouncementResult;
import edu.bingol.backend.event.extras.ExtrasDtos.Certificate;
import edu.bingol.backend.event.extras.ExtrasDtos.CertificateVerification;
import edu.bingol.backend.event.extras.ExtrasDtos.CoOrganizerView;
import edu.bingol.backend.event.extras.ExtrasDtos.FeedbackRequest;
import edu.bingol.backend.event.extras.ExtrasDtos.FeedbackSummary;
import edu.bingol.backend.event.extras.ExtrasDtos.FeedbackView;
import edu.bingol.backend.event.extras.ExtrasDtos.SeriesRequest;
import edu.bingol.backend.event.extras.ExtrasDtos.SeriesView;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** T14 etkinlik ekstralari uclari. Yalnizca HTTP eslemesi ve rate limit; kurallar servislerde. */
@RestController
@RequestMapping("/api")
public class EventExtrasController {

    private static final MediaType ICS = new MediaType("text", "calendar", java.nio.charset.StandardCharsets.UTF_8);

    private final CoOrganizerService coOrganizers;
    private final AnnouncementService announcements;
    private final SeriesService series;
    private final IcsService ics;
    private final EventFeedbackService feedback;
    private final CertificateService certificates;
    private final RateLimiter limiter;
    private final ClientIp clientIp;

    public EventExtrasController(CoOrganizerService coOrganizers, AnnouncementService announcements,
                                 SeriesService series, IcsService ics, EventFeedbackService feedback,
                                 CertificateService certificates, RateLimiter limiter, ClientIp clientIp) {
        this.coOrganizers = coOrganizers;
        this.announcements = announcements;
        this.series = series;
        this.ics = ics;
        this.feedback = feedback;
        this.certificates = certificates;
        this.limiter = limiter;
        this.clientIp = clientIp;
    }

    // ---- ortak organizatorler ----

    @GetMapping("/events/{id}/co-organizers")
    public List<CoOrganizerView> coOrganizers(@PathVariable Long id) {
        return coOrganizers.list(Actor.current(), id);
    }

    @PostMapping("/events/{id}/co-organizers")
    @ResponseStatus(HttpStatus.CREATED)
    public CoOrganizerView addCoOrganizer(@PathVariable Long id, @Valid @RequestBody AddCoOrganizerRequest r) {
        Actor a = Actor.current();
        limiter.check("event-coorg:user:" + a.id(), 20, Duration.ofHours(1));
        return coOrganizers.add(a, id, r.userId());
    }

    @DeleteMapping("/events/{id}/co-organizers/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeCoOrganizer(@PathVariable Long id, @PathVariable Long userId) {
        Actor a = Actor.current();
        limiter.check("event-coorg:user:" + a.id(), 20, Duration.ofHours(1));
        coOrganizers.remove(a, id, userId);
    }

    // ---- toplu duyuru ----

    @PostMapping("/events/{id}/announcements")
    public AnnouncementResult announce(@PathVariable Long id, @Valid @RequestBody AnnouncementRequest r) {
        Actor a = Actor.current();
        limiter.check("event-announce:user:" + a.id(), 10, Duration.ofHours(1));
        return announcements.send(a, id, r.title(), r.message(), Instant.now());
    }

    // ---- ICS ----

    @GetMapping("/events/{id}/ics")
    public ResponseEntity<String> eventIcs(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("event-ics:user:" + a.id(), 30, Duration.ofMinutes(1));
        return icsResponse(ics.single(a, id, Instant.now()), "event-" + id + ".ics");
    }

    @GetMapping("/me/events.ics")
    public ResponseEntity<String> myIcs() {
        Actor a = Actor.current();
        limiter.check("event-ics:user:" + a.id(), 30, Duration.ofMinutes(1));
        return icsResponse(ics.mine(a, Instant.now()), "my-events.ics");
    }

    // ---- haftalik seri ----

    @PostMapping("/events/{id}/series")
    @ResponseStatus(HttpStatus.CREATED)
    public SeriesView createSeries(@PathVariable Long id, @Valid @RequestBody SeriesRequest r) {
        Actor a = Actor.current();
        limiter.check("event-series:user:" + a.id(), 5, Duration.ofHours(1));
        return series.create(a, id, r.count(), Instant.now());
    }

    @GetMapping("/events/{id}/series")
    public SeriesView getSeries(@PathVariable Long id) {
        return series.get(Actor.current(), id);
    }

    /** Bu etkinlik ve sonraki tum tekrarlar iptal edilir; tek bir etkinlik icin DELETE /events/{id}. */
    @DeleteMapping("/events/{id}/series")
    public Map<String, Integer> cancelSeries(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("event-series-cancel:user:" + a.id(), 10, Duration.ofHours(1));
        return Map.of("cancelled", series.cancelFromHere(a, id, Instant.now()));
    }

    // ---- anket ----

    @PostMapping("/events/{id}/feedback")
    @ResponseStatus(HttpStatus.CREATED)
    public FeedbackView submitFeedback(@PathVariable Long id, @Valid @RequestBody FeedbackRequest r) {
        Actor a = Actor.current();
        limiter.check("event-feedback:user:" + a.id(), 20, Duration.ofHours(1));
        return feedback.submit(a, id, r.rating(), r.comment(), Instant.now());
    }

    @GetMapping("/events/{id}/feedback/mine")
    public FeedbackView myFeedback(@PathVariable Long id) {
        return feedback.mine(Actor.current(), id);
    }

    @GetMapping("/events/{id}/feedback/summary")
    public FeedbackSummary feedbackSummary(@PathVariable Long id) {
        return feedback.summary(Actor.current(), id);
    }

    @GetMapping("/events/{id}/feedback")
    public CursorPage<FeedbackView> feedbackList(@PathVariable Long id,
                                                 @RequestParam(required = false) Long cursor,
                                                 @RequestParam(defaultValue = "20") int size) {
        return feedback.list(Actor.current(), id, cursor, size);
    }

    // ---- sertifika ----

    @GetMapping("/events/{id}/certificate")
    public Certificate certificate(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("event-cert:user:" + a.id(), 30, Duration.ofMinutes(1));
        return certificates.issue(a, id);
    }

    /** Herkese acik; kod tahminine karsi IP basina siki sinir. */
    @GetMapping("/certificates/verify/{code}")
    public CertificateVerification verify(@PathVariable String code, HttpServletRequest req) {
        limiter.check("cert-verify:ip:" + clientIp.of(req), 20, Duration.ofMinutes(1));
        return certificates.verify(code);
    }

    private static ResponseEntity<String> icsResponse(String body, String filename) {
        return ResponseEntity.ok()
                .contentType(ICS)
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment().filename(filename).build().toString())
                .body(body);
    }
}
