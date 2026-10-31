package edu.bingol.backend.poll;

import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.poll.PollDtos.CreateRequest;
import edu.bingol.backend.poll.PollDtos.PollPage;
import edu.bingol.backend.poll.PollDtos.PollView;
import edu.bingol.backend.poll.PollDtos.UpdateRequest;
import edu.bingol.backend.poll.PollDtos.VoteRequest;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
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

/** Anket uclari: yalniz HTTP eslemesi + hiz siniri; kurallar PollService / PollVoteService'te. */
@RestController
@RequestMapping("/api/polls")
public class PollController {

    private final PollService service;
    private final PollVoteService voteService;
    private final PollMenuService menuService;
    private final PollAdminService adminService;
    private final RateLimiter limiter;

    public PollController(PollService service, PollVoteService voteService, PollMenuService menuService,
                          PollAdminService adminService, RateLimiter limiter) {
        this.service = service;
        this.voteService = voteService;
        this.menuService = menuService;
        this.adminService = adminService;
        this.limiter = limiter;
    }

    @GetMapping
    public PollPage list(@RequestParam(defaultValue = "open") String scope, @RequestParam(required = false) Long cursor,
                         @RequestParam(defaultValue = "20") int size) {
        Actor a = read();
        return service.list(a, scope, cursor, size);
    }

    /** Bugunku menu anketi; yemek listesi yoksa 204. */
    @GetMapping("/menu/today")
    public ResponseEntity<PollView> menuToday() {
        Actor a = read();
        return menuService.today(a).map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.noContent().build());
    }

    @GetMapping("/{id}")
    public PollView get(@PathVariable Long id) {
        return service.get(read(), id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public PollView create(@RequestBody CreateRequest req) {
        Actor a = Actor.current();
        limiter.check("poll:create:" + a.id(), 10, Duration.ofHours(1));
        return service.create(a, req);
    }

    @PostMapping("/{id}/vote")
    public PollView vote(@PathVariable Long id, @RequestBody VoteRequest req) {
        Actor a = Actor.current();
        limiter.check("poll:vote:" + a.id(), 60, Duration.ofMinutes(1));
        return voteService.vote(a, id, req);
    }

    @DeleteMapping("/{id}/vote")
    public PollView retract(@PathVariable Long id) {
        Actor a = Actor.current();
        limiter.check("poll:vote:" + a.id(), 60, Duration.ofMinutes(1));
        return voteService.retract(a, id);
    }

    @PatchMapping("/{id}")
    public PollView update(@PathVariable Long id, @RequestBody UpdateRequest req) {
        return service.update(write(), id, req);
    }

    @PostMapping("/{id}/close")
    public PollView close(@PathVariable Long id) {
        return service.close(write(), id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        service.delete(write(), id);
    }

    /** Sonuc CSV'si (kimliksiz): olusturan / kulup yoneticisi / ADMIN. */
    @GetMapping("/{id}/export.csv")
    public ResponseEntity<byte[]> export(@PathVariable Long id) {
        Actor a = read();
        String csv = adminService.csvFor(a, id);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"poll-" + id + ".csv\"")
                .contentType(new MediaType("text", "csv", StandardCharsets.UTF_8))
                .body(csv.getBytes(StandardCharsets.UTF_8));
    }

    private Actor read() {
        Actor a = Actor.current();
        limiter.check("poll:read:" + a.id(), 120, Duration.ofMinutes(1));
        return a;
    }

    private Actor write() {
        Actor a = Actor.current();
        limiter.check("poll:write:" + a.id(), 60, Duration.ofMinutes(1));
        return a;
    }
}
