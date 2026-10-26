package edu.bingol.backend.mail;

import java.time.Duration;

/** Ustel geri cekilme: basarisiz deneme sayisina gore bir sonraki denemeye kadar bekleme. */
final class MailBackoff {

    private static final Duration[] STEPS = {
            Duration.ofMinutes(1), Duration.ofMinutes(5), Duration.ofMinutes(30),
            Duration.ofHours(2), Duration.ofHours(12)
    };

    private MailBackoff() {
    }

    /** @param failedAttempts o ana kadar basarisiz olan deneme sayisi (>= 1) */
    static Duration delay(int failedAttempts) {
        int idx = Math.min(Math.max(failedAttempts, 1), STEPS.length) - 1;
        return STEPS[idx];
    }
}
