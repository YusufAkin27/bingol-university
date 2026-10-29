package edu.bingol.backend.observability;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Sistem durumu (yalniz ADMIN: /api/admin/** SecurityConfig'te ADMIN; POST'lar AuditInterceptor ile denetlenir).
 * Sozlesme: docs/ADMIN_API.md "Sistem durumu".
 */
@RestController
@RequestMapping("/api/admin/system")
public class SystemOverviewController {

    public record IdsRequest(List<Long> ids) {
    }

    private final SystemOverviewService overview;
    private final DeadLetterService deadLetters;
    private final RateLimiter limiter;

    public SystemOverviewController(SystemOverviewService overview, DeadLetterService deadLetters,
                                    RateLimiter limiter) {
        this.overview = overview;
        this.deadLetters = deadLetters;
        this.limiter = limiter;
    }

    @GetMapping("/overview")
    public SystemOverviewService.Overview overview() {
        limiter.check("admin:system:" + adminKey(), 120, Duration.ofMinutes(1));
        return overview.evaluate(LocaleContextHolder.getLocale());
    }

    @GetMapping("/dead-letters/mail")
    public List<DeadLetterService.MailDead> deadMail(@RequestParam(defaultValue = "50") int limit) {
        limiter.check("admin:system:" + adminKey(), 120, Duration.ofMinutes(1));
        return deadLetters.listMail(limit);
    }

    @GetMapping("/dead-letters/push")
    public List<DeadLetterService.PushDead> deadPush(@RequestParam(defaultValue = "50") int limit) {
        limiter.check("admin:system:" + adminKey(), 120, Duration.ofMinutes(1));
        return deadLetters.listPush(limit);
    }

    /** Govde bos ya da {"ids":[]} = tum olu mailler. */
    @PostMapping("/dead-letters/mail/retry")
    public Map<String, Integer> retryMail(@RequestBody(required = false) IdsRequest body) {
        limiter.check("admin:system:write:" + adminKey(), 30, Duration.ofMinutes(10));
        DeadLetterService.MailRetryResult r = deadLetters.retryMail(ids(body));
        return Map.of("requeued", r.requeued(), "skipped", r.skipped());
    }

    @PostMapping("/dead-letters/push/retry")
    public Map<String, Integer> retryPush(@RequestBody(required = false) IdsRequest body) {
        limiter.check("admin:system:write:" + adminKey(), 30, Duration.ofMinutes(10));
        return Map.of("requeued", deadLetters.retryPush(ids(body)));
    }

    /** Silme icin kimlik listesi ZORUNLU. */
    @PostMapping("/dead-letters/mail/delete")
    public Map<String, Integer> deleteMail(@RequestBody IdsRequest body) {
        limiter.check("admin:system:write:" + adminKey(), 30, Duration.ofMinutes(10));
        return Map.of("deleted", deadLetters.deleteMail(requireIds(body)));
    }

    @PostMapping("/dead-letters/push/delete")
    public Map<String, Integer> deletePush(@RequestBody IdsRequest body) {
        limiter.check("admin:system:write:" + adminKey(), 30, Duration.ofMinutes(10));
        return Map.of("deleted", deadLetters.deletePush(requireIds(body)));
    }

    private static List<Long> ids(IdsRequest body) {
        if (body == null || body.ids() == null || body.ids().isEmpty()) {
            return List.of();
        }
        return requireIds(body);
    }

    private static List<Long> requireIds(IdsRequest body) {
        if (body == null || body.ids() == null || body.ids().isEmpty()
                || body.ids().size() > DeadLetterService.MAX_IDS || body.ids().stream().anyMatch(i -> i == null)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_ERROR", "Geçersiz istek");
        }
        return body.ids();
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
