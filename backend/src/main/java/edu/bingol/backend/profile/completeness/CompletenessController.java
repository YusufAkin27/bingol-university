package edu.bingol.backend.profile.completeness;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.profile.ProfileService;
import edu.bingol.backend.profile.completeness.CompletenessService.Completeness;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class CompletenessController {

    private final ProfileService profiles;
    private final CompletenessService completeness;
    private final RateLimiter limiter;

    public CompletenessController(ProfileService profiles, CompletenessService completeness, RateLimiter limiter) {
        this.profiles = profiles;
        this.completeness = completeness;
        this.limiter = limiter;
    }

    @GetMapping("/api/users/me/completeness")
    public Completeness get() {
        Long uid = CurrentUser.id();
        limiter.check("profile-completeness:user:" + uid, 60, Duration.ofMinutes(1));
        return completeness.of(profiles.get(uid));
    }
}
