package edu.bingol.backend.notification.live;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.Duration;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * iOS Canli Etkinlik kayit uclari (mobil: lib/core/live). PUT idempotenttir (activityId anahtar); jeton yenilenince
 * ayni uca tekrar yazilir. Sohbet/arkadaslik/duyuru icin kayit YOKTUR: yalniz EVENT ve EXAM.
 */
@RestController
@RequestMapping("/api/live-activities")
public class LiveActivityController {

    public record RegisterRequest(@NotNull @Pattern(regexp = "EVENT|EXAM") String kind,
                                  @NotNull @Positive Long refId,
                                  @Size(max = 400) String pushToken) {}

    private final LiveActivityService service;
    private final RateLimiter limiter;

    public LiveActivityController(LiveActivityService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    /** Sunucu Canli Etkinlik push'u yapilandirildi mi (istemci durumu durust gostersin). */
    @GetMapping("/status")
    public LiveActivityService.Status status() {
        limiter.check("live-act-read:" + CurrentUser.id(), 60, Duration.ofMinutes(1));
        return service.status();
    }

    @PutMapping("/{activityId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void register(@PathVariable @NotBlank @Size(max = 64) @Pattern(regexp = "[A-Za-z0-9-]+") String activityId,
                         @Valid @RequestBody RegisterRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("live-act-write:" + uid, 60, Duration.ofHours(1));
        service.register(uid, new LiveActivityService.Registration(activityId, LiveActivity.Kind.valueOf(r.kind()),
                r.refId(), r.pushToken()), Instant.now());
    }

    @DeleteMapping("/{activityId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void end(@PathVariable @Size(max = 64) @Pattern(regexp = "[A-Za-z0-9-]+") String activityId) {
        Long uid = CurrentUser.id();
        limiter.check("live-act-write:" + uid, 60, Duration.ofHours(1));
        service.end(uid, activityId, Instant.now());
    }
}
