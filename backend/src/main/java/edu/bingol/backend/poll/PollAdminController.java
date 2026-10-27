package edu.bingol.backend.poll;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.poll.PollDtos.AdminPollPage;
import edu.bingol.backend.poll.PollDtos.AdminStats;
import edu.bingol.backend.poll.PollDtos.BulkRequest;
import edu.bingol.backend.poll.PollDtos.BulkResult;
import edu.bingol.backend.poll.PollDtos.PollView;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
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

/**
 * Yonetici anket uclari (/api/admin/** => ROLE_ADMIN; yazma islemleri AuditInterceptor ile denetlenir).
 * Sonuclar her zaman gorunur; kim ne oy verdi hicbir uc tarafindan gosterilmez.
 */
@RestController
@RequestMapping("/api/admin/polls")
public class PollAdminController {

    private final PollAdminService admin;
    private final PollService service;
    private final RateLimiter limiter;

    public PollAdminController(PollAdminService admin, PollService service, RateLimiter limiter) {
        this.admin = admin;
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping
    public AdminPollPage list(@RequestParam(required = false) String status, @RequestParam(required = false) String scope,
                              @RequestParam(required = false) String q, @RequestParam(defaultValue = "0") int page,
                              @RequestParam(defaultValue = "20") int size) {
        return admin.list(status, scope, q, page, size);
    }

    @GetMapping("/stats")
    public AdminStats stats() {
        return admin.stats();
    }

    @GetMapping("/{id}")
    public PollView get(@PathVariable Long id) {
        return admin.get(actor(), id);
    }

    @PostMapping("/{id}/close")
    public PollView close(@PathVariable Long id) {
        Actor a = write();
        service.close(a, id);
        return admin.get(a, id);
    }

    @PostMapping("/{id}/cancel")
    public PollView cancel(@PathVariable Long id) {
        Actor a = write();
        service.cancel(id);
        return admin.get(a, id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        service.delete(write(), id);
    }

    @PostMapping("/bulk")
    public BulkResult bulk(@RequestBody BulkRequest req) {
        return admin.bulk(write(), req.ids(), req.action());
    }

    @GetMapping("/{id}/export.csv")
    public ResponseEntity<byte[]> export(@PathVariable Long id) {
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"poll-" + id + ".csv\"")
                .contentType(new MediaType("text", "csv", StandardCharsets.UTF_8))
                .body(admin.csv(id).getBytes(StandardCharsets.UTF_8));
    }

    /** Basic auth yoneticisinde kullanici kimligi yoktur: -1 (oy/olusturan eslesmesi olmaz). */
    private static Actor actor() {
        try {
            return new Actor(CurrentUser.id(), true);
        } catch (RuntimeException e) {
            return new Actor(-1L, true);
        }
    }

    private Actor write() {
        Actor a = actor();
        limiter.check("poll:admin:" + a.id(), 120, Duration.ofMinutes(1));
        return a;
    }
}
