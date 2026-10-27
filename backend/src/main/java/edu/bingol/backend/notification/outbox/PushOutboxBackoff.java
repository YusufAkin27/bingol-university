package edu.bingol.backend.notification.outbox;

import java.time.Duration;

/** Ustel geri cekilme: 30 sn, 2 dk, 10 dk, 1 sa, 6 sa. */
final class PushOutboxBackoff {

    private static final Duration[] STEPS = {
            Duration.ofSeconds(30), Duration.ofMinutes(2), Duration.ofMinutes(10), Duration.ofHours(1), Duration.ofHours(6)
    };

    private PushOutboxBackoff() {
    }

    /** @param failedAttempts o ana kadar basarisiz deneme sayisi (>= 1) */
    static Duration delay(int failedAttempts) {
        return STEPS[Math.min(Math.max(failedAttempts, 1), STEPS.length) - 1];
    }
}
