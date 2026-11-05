package edu.bingol.backend.forum.notify;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.notify.ForumNotificationPrefService.PrefsUpdate;
import edu.bingol.backend.forum.notify.ForumNotificationPrefService.PrefsView;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** {@code GET|PUT /api/forum/notification-prefs}: forum bildirim ayarlari (tum forum, konu, yanit, begeni, takip). */
@RestController
@RequestMapping("/api/forum/notification-prefs")
public class ForumNotificationPrefController {

    private final ForumNotificationPrefService prefs;
    private final RateLimiter limiter;

    public ForumNotificationPrefController(ForumNotificationPrefService prefs, RateLimiter limiter) {
        this.prefs = prefs;
        this.limiter = limiter;
    }

    @GetMapping
    public PrefsView get() {
        Long uid = CurrentUser.id();
        limiter.check("fnp:get:" + uid, 120, Duration.ofMinutes(1));
        return prefs.get(uid);
    }

    @PutMapping
    public PrefsView update(@Valid @RequestBody PrefsUpdate r) {
        Long uid = CurrentUser.id();
        limiter.check("fnp:put:" + uid, 60, Duration.ofMinutes(1));
        return prefs.update(uid, r);
    }
}
