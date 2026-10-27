package edu.bingol.backend.notification.outbox;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import java.util.Map;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Yonetici: push kuyruk ozeti ve olu kayitlari yeniden deneme (/api/admin/** => ROLE_ADMIN; yazma denetlenir). */
@RestController
@RequestMapping("/api/admin/push/outbox")
@ConditionalOnProperty(name = "app.push.outbox.enabled", havingValue = "true", matchIfMissing = true)
public class PushOutboxAdminController {

    private final PushOutboxService outbox;
    private final RateLimiter limiter;

    public PushOutboxAdminController(PushOutboxService outbox, RateLimiter limiter) {
        this.outbox = outbox;
        this.limiter = limiter;
    }

    @GetMapping("/stats")
    public PushOutboxService.Stats stats() {
        return outbox.stats();
    }

    @PostMapping("/retry-dead")
    public Map<String, Integer> retryDead() {
        limiter.check("pushoutbox:retry:" + adminKey(), 10, Duration.ofMinutes(1));
        return Map.of("requeued", outbox.retryDead());
    }

    /** Basic auth yoneticisinde kullanici kimligi yoktur: ortak anahtar. */
    private static String adminKey() {
        try {
            return String.valueOf(CurrentUser.id());
        } catch (RuntimeException e) {
            return "basic";
        }
    }
}
