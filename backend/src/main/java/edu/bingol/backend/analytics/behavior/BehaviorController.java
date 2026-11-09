package edu.bingol.backend.analytics.behavior;

import edu.bingol.backend.admin.AuditRead;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.Actions;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.Flows;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.Overview;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.ScreensPage;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.UserDetail;
import edu.bingol.backend.analytics.behavior.BehaviorDtos.UsersPage;
import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Yonetici kullanici davranis analizi (/api/admin/analytics/behavior/**). Ozet/ekran/akis/eylem uclari
 * `analytics.read`; kullanici bazli uclar (`/users`, `/users/{id}`) `users.pii` ister ve her cagri denetim kaydina
 * yazilir (AdminPermissionPolicy + AuditRead). Controller yalniz HTTP + hiz siniri; ayrinti {@link BehaviorService}.
 */
@RestController
@RequestMapping("/api/admin/analytics/behavior")
public class BehaviorController {

    /** Yonetici basina dakikada en cok bu kadar agir sorgu (ham tablo uzerinde pencere sorgulari). */
    static final int PER_MINUTE = 60;

    private final BehaviorService service;
    private final RateLimiter limiter;

    public BehaviorController(BehaviorService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping("/overview")
    public Overview overview(@RequestParam(required = false) String from, @RequestParam(required = false) String to,
                             Authentication auth) {
        limit(auth);
        return service.overview(from, to);
    }

    @GetMapping("/screens")
    public ScreensPage screens(@RequestParam(required = false) String from, @RequestParam(required = false) String to,
                               @RequestParam(required = false) String sort, @RequestParam(required = false) String dir,
                               @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size,
                               Authentication auth) {
        limit(auth);
        return service.screens(from, to, sort, dir, page, size);
    }

    @GetMapping("/flows")
    public Flows flows(@RequestParam(required = false) String from, @RequestParam(required = false) String to,
                       Authentication auth) {
        limit(auth);
        return service.flows(from, to);
    }

    @GetMapping("/actions")
    public Actions actions(@RequestParam(required = false) String from, @RequestParam(required = false) String to,
                           Authentication auth) {
        limit(auth);
        return service.actions(from, to);
    }

    /** Kisisel veri (kullanici bazli davranis): okuma da denetim kaydina yazilir. */
    @AuditRead
    @GetMapping("/users")
    public UsersPage users(@RequestParam(required = false) String from, @RequestParam(required = false) String to,
                           @RequestParam(required = false) String sort, @RequestParam(required = false) String dir,
                           @RequestParam(required = false) String q, @RequestParam(defaultValue = "0") int page,
                           @RequestParam(defaultValue = "20") int size, Authentication auth) {
        limit(auth);
        return service.users(from, to, sort, dir, q, page, size);
    }

    @AuditRead
    @GetMapping("/users/{id}")
    public UserDetail userDetail(@PathVariable long id, @RequestParam(required = false) Integer days,
                                 @RequestParam(required = false) String from, @RequestParam(required = false) String to,
                                 Authentication auth) {
        limit(auth);
        return service.userDetail(id, days, from, to);
    }

    private void limit(Authentication auth) {
        limiter.check("behavior:admin:" + (auth == null ? "anon" : auth.getName()), PER_MINUTE, Duration.ofMinutes(1));
    }
}
