package edu.bingol.backend.forum.moderation;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.moderation.ForumMuteService.MutePage;
import java.time.Duration;
import java.util.Map;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Forum sessize alma uclari (kullanici). Yazma: saatte 60 (sessize al/kaldir dongusu ve kimlik taramasi tavani). */
@RestController
@RequestMapping("/api/forum/mutes")
public class ForumMuteController {

    private final ForumMuteService mutes;
    private final RateLimiter limiter;

    public ForumMuteController(ForumMuteService mutes, RateLimiter limiter) {
        this.mutes = mutes;
        this.limiter = limiter;
    }

    @GetMapping
    public MutePage list(@RequestParam(required = false) String cursor, @RequestParam(defaultValue = "15") int size) {
        Long me = CurrentUser.id();
        limiter.check("fmute:read:" + me, 120, Duration.ofMinutes(1));
        return mutes.list(me, cursor, size);
    }

    @PutMapping("/{userId}")
    public Map<String, Boolean> mute(@PathVariable Long userId) {
        Long me = CurrentUser.id();
        limiter.check("fmute:" + me, 60, Duration.ofHours(1));
        mutes.mute(me, userId);
        return Map.of("muted", true);
    }

    @DeleteMapping("/{userId}")
    public Map<String, Boolean> unmute(@PathVariable Long userId) {
        Long me = CurrentUser.id();
        limiter.check("fmute:" + me, 60, Duration.ofHours(1));
        mutes.unmute(me, userId);
        return Map.of("muted", false);
    }
}
