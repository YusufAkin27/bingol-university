package edu.bingol.backend.profile.onboarding;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.profile.dto.ProfileDtos.ProfileView;
import edu.bingol.backend.profile.onboarding.OnboardingDtos.OnboardingRequest;
import edu.bingol.backend.profile.onboarding.OnboardingDtos.OnboardingResponse;
import edu.bingol.backend.profile.onboarding.OnboardingDtos.UsernameAvailability;
import edu.bingol.backend.profile.onboarding.OnboardingDtos.UsernameRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Profil tamamlama (onboarding) ve kullanici adi uclari. Hepsi OTURUMLUDUR (musaitlik sorgusu kullanici dizinini
 * taratmasin). Tamamlanmamis profilde yalniz {@code PUT /me/onboarding} (ve GET'ler) serbesttir
 * ({@code ProfileIncompleteWriteFilter}).
 */
@RestController
@RequestMapping("/api/users")
public class OnboardingController {

    private final OnboardingService onboarding;
    private final RateLimiter limiter;

    public OnboardingController(OnboardingService onboarding, RateLimiter limiter) {
        this.onboarding = onboarding;
        this.limiter = limiter;
    }

    /** `?u=<ad>` -> {available, reason?: TAKEN|INVALID|RESERVED}; kullanici basina dakikada 30. */
    @GetMapping("/username-available")
    public UsernameAvailability usernameAvailable(@RequestParam("u") String u) {
        Long uid = CurrentUser.id();
        limiter.check("username-avail:user:" + uid, 30, Duration.ofMinutes(1));
        limiter.check("username-avail-day:user:" + uid, 600, Duration.ofDays(1));
        return onboarding.availability(uid, u.length() > 64 ? u.substring(0, 64) : u);
    }

    /** Idempotent profil tamamlama; kullanici adi yarisi 409 USERNAME_TAKEN. */
    @PutMapping("/me/onboarding")
    public OnboardingResponse onboard(@Valid @RequestBody OnboardingRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("onboarding:user:" + uid, 20, Duration.ofHours(1));
        return onboarding.onboard(uid, r);
    }

    /** Mevcut (eski) hesaplara istege bagli kullanici adi atama/degistirme (tamamlanmis profilde). */
    @PutMapping("/me/username")
    public ProfileView setUsername(@Valid @RequestBody UsernameRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("username-set:user:" + uid, 10, Duration.ofHours(1));
        return onboarding.setUsername(uid, r.username());
    }
}
