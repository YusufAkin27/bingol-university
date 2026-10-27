package edu.bingol.backend.accessban;

import edu.bingol.backend.accessban.AccessBanDtos.*;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Duration;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
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
 * Erisim engeli yonetimi (/api/admin/** => yalniz ADMIN; yazma islemleri AuditInterceptor ile denetim kaydina,
 * liste/cihaz goruntuleme AuditRecorder.shouldAudit ile yazilir). Is kurali {@link AccessBanService}'tedir.
 */
@RestController
@RequestMapping("/api/admin")
public class AdminAccessBanController {

    private final AccessBanService service;
    private final ClientContexts contexts;
    private final RateLimiter limiter;

    public AdminAccessBanController(AccessBanService service, ClientContexts contexts, RateLimiter limiter) {
        this.service = service;
        this.contexts = contexts;
        this.limiter = limiter;
    }

    @GetMapping("/access-bans")
    public CursorPage<BanView> list(@RequestParam(required = false) String kind,
                                    @RequestParam(required = false) Boolean active,
                                    @RequestParam(required = false) String q,
                                    @RequestParam(required = false) Long cursor,
                                    @RequestParam(defaultValue = "20") int size, Authentication auth) {
        limit(auth, "read", 240, Duration.ofMinutes(1));
        return service.list(kind, active, q, cursor, size);
    }

    @PostMapping("/access-bans")
    @ResponseStatus(HttpStatus.CREATED)
    public BlockAccessResult create(@RequestBody CreateBanRequest r, Authentication auth, HttpServletRequest http) {
        limit(auth, "write", 60, Duration.ofMinutes(1));
        return service.create(actor(auth), r, contexts.of(http));
    }

    @PatchMapping("/access-bans/{id}")
    public BanView patch(@PathVariable Long id, @RequestBody PatchBanRequest r, Authentication auth) {
        limit(auth, "write", 60, Duration.ofMinutes(1));
        return service.patch(id, r);
    }

    @DeleteMapping("/access-bans/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remove(@PathVariable Long id, Authentication auth) {
        limit(auth, "write", 60, Duration.ofMinutes(1));
        service.remove(id);
    }

    @PostMapping("/access-bans/bulk")
    @ResponseStatus(HttpStatus.CREATED)
    public BulkResult bulk(@RequestBody BulkRequest r, Authentication auth, HttpServletRequest http) {
        limit(auth, "bulk", 10, Duration.ofMinutes(10));
        return service.bulk(actor(auth), r, contexts.of(http));
    }

    @GetMapping("/access-bans/stats")
    public Stats stats(Authentication auth) {
        limit(auth, "read", 240, Duration.ofMinutes(1));
        return service.stats();
    }

    @GetMapping("/access-bans/{id}/attempts")
    public CursorPage<AttemptView> attempts(@PathVariable Long id, @RequestParam(required = false) Long cursor,
                                            @RequestParam(defaultValue = "20") int size, Authentication auth) {
        limit(auth, "read", 240, Duration.ofMinutes(1));
        return service.attempts(id, cursor, size);
    }

    // ---- anonimlestirici aglar (Tor cikis / VPN / veri merkezi araliklari; yonetici yuklemesi)

    @PostMapping("/access-bans/anonymizers")
    @ResponseStatus(HttpStatus.CREATED)
    public AnonymizerUploadResult uploadAnonymizers(@RequestBody AnonymizerUpload r, Authentication auth) {
        limit(auth, "bulk", 10, Duration.ofMinutes(10));
        return service.uploadAnonymizers(r);
    }

    @GetMapping("/access-bans/anonymizers")
    public AnonymizerList anonymizers(@RequestParam(required = false) Long cursor,
                                      @RequestParam(defaultValue = "50") int size, Authentication auth) {
        limit(auth, "read", 240, Duration.ofMinutes(1));
        return service.listAnonymizers(cursor, size);
    }

    @DeleteMapping("/access-bans/anonymizers/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAnonymizer(@PathVariable Long id, Authentication auth) {
        limit(auth, "write", 60, Duration.ofMinutes(1));
        service.deleteAnonymizer(id);
    }

    /** `source` verilen etikete sahip tum araliklari siler (bos = etiketsizler). */
    @DeleteMapping("/access-bans/anonymizers")
    public Map<String, Integer> deleteAnonymizersBySource(@RequestParam(required = false) String source,
                                                          Authentication auth) {
        limit(auth, "write", 60, Duration.ofMinutes(1));
        return Map.of("deleted", service.deleteAnonymizersBySource(source));
    }

    // ---- kullanici bazli

    @GetMapping("/users/{id}/devices")
    public UserDevices devices(@PathVariable Long id, Authentication auth) {
        limit(auth, "read", 240, Duration.ofMinutes(1));
        return service.userDevices(id);
    }

    @PostMapping("/users/{id}/block-access")
    public BlockAccessResult blockAccess(@PathVariable Long id, @RequestBody BlockAccessRequest r,
                                         Authentication auth, HttpServletRequest http) {
        limit(auth, "write", 60, Duration.ofMinutes(1));
        return service.blockUser(actor(auth), id, r, contexts.of(http));
    }

    /** Basic auth yoneticisinin principal'i Long degildir; kimlik null kalir. */
    private static Long actor(Authentication auth) {
        return auth != null && auth.getPrincipal() instanceof Long l ? l : null;
    }

    private void limit(Authentication auth, String bucket, int max, Duration window) {
        Long id = actor(auth);
        limiter.check("accessban:" + bucket + ":" + (id == null ? "basic" : id), max, window);
    }
}
