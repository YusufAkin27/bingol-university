package edu.bingol.backend.event.admission;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.event.admission.AdmissionDtos.Action;
import edu.bingol.backend.event.admission.AdmissionDtos.AdmissionSummary;
import edu.bingol.backend.event.admission.AdmissionDtos.ApplicantView;
import edu.bingol.backend.event.admission.AdmissionDtos.ApplicationView;
import edu.bingol.backend.event.admission.AdmissionDtos.ApplyRequest;
import edu.bingol.backend.event.admission.AdmissionDtos.ConfigRequest;
import edu.bingol.backend.event.admission.AdmissionDtos.ConfigView;
import edu.bingol.backend.event.admission.AdmissionDtos.DecisionItem;
import edu.bingol.backend.event.admission.AdmissionDtos.DecisionRequest;
import edu.bingol.backend.event.admission.AdmissionDtos.DecisionResult;
import edu.bingol.backend.event.admission.AdmissionDtos.SingleDecisionRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Etkinlik katilim (admission) uclari. Yalnizca HTTP eslemesi ve rate limit; kurallar EventAdmissionService'te. */
@RestController
@RequestMapping("/api")
public class EventAdmissionController {

    private final EventAdmissionService admission;
    private final RateLimiter limiter;

    public EventAdmissionController(EventAdmissionService admission, RateLimiter limiter) {
        this.admission = admission;
        this.limiter = limiter;
    }

    // ---- yapilandirma (organizator yazar, herkes okur) ----

    @GetMapping("/events/{id}/admission")
    public ConfigView config(@PathVariable Long id) {
        return admission.config(Actor.current(), id);
    }

    @PutMapping("/events/{id}/admission")
    public ConfigView setConfig(@PathVariable Long id, @Valid @RequestBody ConfigRequest r) {
        Actor a = Actor.current();
        limiter.check("event-admission-cfg:user:" + a.id(), 30, Duration.ofMinutes(1));
        return admission.setConfig(a, id, r);
    }

    // ---- basvuran ----

    @PostMapping("/events/{id}/applications")
    @ResponseStatus(HttpStatus.CREATED)
    public ApplicationView apply(@PathVariable Long id, @Valid @RequestBody(required = false) ApplyRequest r) {
        Actor a = Actor.current();
        limiter.check("event-apply:user:" + a.id(), 20, Duration.ofMinutes(1));
        return admission.apply(a, id, r);
    }

    @GetMapping("/events/{id}/applications/mine")
    public ApplicationView mine(@PathVariable Long id) {
        return admission.mine(Actor.current(), id);
    }

    @DeleteMapping("/events/{id}/applications/mine")
    public ApplicationView withdraw(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("event-withdraw:user:" + a.id(), 20, Duration.ofMinutes(1));
        return admission.withdraw(a, id);
    }

    @GetMapping("/me/applications")
    public CursorPage<ApplicationView> myApplications(@RequestParam(required = false) Long cursor,
                                                      @RequestParam(defaultValue = "20") int size) {
        return admission.myApplications(Actor.current(), cursor, size);
    }

    // ---- organizator ----

    @GetMapping("/events/{id}/applications")
    public CursorPage<ApplicantView> list(@PathVariable Long id,
                                          @RequestParam(required = false) EventApplication.Status status,
                                          @RequestParam(required = false) Long cursor,
                                          @RequestParam(defaultValue = "50") int size) {
        return admission.list(Actor.current(), id, status, cursor, size);
    }

    @GetMapping("/events/{id}/applications/summary")
    public AdmissionSummary summary(@PathVariable Long id) {
        return admission.summary(Actor.current(), id);
    }

    /** Toplu karar (en fazla 100 kimlik): ACCEPT | REJECT | WAITLIST. Her kimligin sonucu ayri doner. */
    @PostMapping("/events/{id}/applications/decisions")
    public DecisionResult decide(@PathVariable Long id, @Valid @RequestBody DecisionRequest r) {
        Actor a = Actor.current();
        limiter.check("event-decide:user:" + a.id(), 60, Duration.ofMinutes(1));
        return admission.decide(a, id, r.ids(), r.action(), r.reason());
    }

    @PostMapping("/events/{id}/applications/{appId}/accept")
    public DecisionItem accept(@PathVariable Long id, @PathVariable Long appId) {
        return one(id, appId, Action.ACCEPT, null);
    }

    @PostMapping("/events/{id}/applications/{appId}/reject")
    public DecisionItem reject(@PathVariable Long id, @PathVariable Long appId,
                               @Valid @RequestBody(required = false) SingleDecisionRequest r) {
        return one(id, appId, Action.REJECT, r == null ? null : r.reason());
    }

    @PostMapping("/events/{id}/applications/{appId}/waitlist")
    public DecisionItem waitlist(@PathVariable Long id, @PathVariable Long appId) {
        return one(id, appId, Action.WAITLIST, null);
    }

    /** Katilimciyi cikarir (kabul edilmis ya da dogrudan katilmis). */
    @DeleteMapping("/events/{id}/participants/{userId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeParticipant(@PathVariable Long id, @PathVariable Long userId) {
        Actor a = Actor.current();
        limiter.check("event-remove:user:" + a.id(), 60, Duration.ofMinutes(1));
        admission.removeParticipant(a, id, userId);
    }

    private DecisionItem one(Long id, Long appId, Action action, String reason) {
        Actor a = Actor.current();
        limiter.check("event-decide:user:" + a.id(), 60, Duration.ofMinutes(1));
        return admission.decideOne(a, id, appId, action, reason);
    }
}
