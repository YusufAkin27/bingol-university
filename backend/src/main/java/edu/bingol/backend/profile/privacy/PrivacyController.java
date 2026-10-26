package edu.bingol.backend.profile.privacy;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.profile.privacy.PrivacyDtos.PrivacyView;
import edu.bingol.backend.profile.privacy.PrivacyDtos.UpdatePrivacyRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users/me/privacy")
public class PrivacyController {

    private final PrivacyService privacy;
    private final RateLimiter limiter;

    public PrivacyController(PrivacyService privacy, RateLimiter limiter) {
        this.privacy = privacy;
        this.limiter = limiter;
    }

    @GetMapping
    public PrivacyView get() {
        return PrivacyView.of(privacy.get(CurrentUser.id()));
    }

    @PatchMapping
    public PrivacyView update(@Valid @RequestBody UpdatePrivacyRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("profile-privacy:user:" + uid, 30, Duration.ofHours(1));
        return PrivacyView.of(privacy.update(uid, r));
    }
}
