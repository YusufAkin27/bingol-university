package edu.bingol.backend.notification;

import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.stereotype.Component;

/** /actuator/health -> fcm: etkin/devre disi ve son hata sayilari. Devre disi olmak sagligi bozmaz (UP). */
@Component("fcm")
public class FcmHealthIndicator implements HealthIndicator {

    private final PushDispatcher dispatcher;

    public FcmHealthIndicator(PushDispatcher dispatcher) {
        this.dispatcher = dispatcher;
    }

    @Override
    public Health health() {
        Health.Builder b = Health.up()
                .withDetail("enabled", dispatcher.fcmEnabled())
                .withDetail("projectId", String.valueOf(dispatcher.fcmCheck(false).projectId()))
                .withDetail("delivered", dispatcher.deliveredCount())
                .withDetail("failures", dispatcher.failureCount())
                .withDetail("retries", dispatcher.retryCount());
        if (dispatcher.lastFailureAt() != null) {
            b.withDetail("lastFailureAt", dispatcher.lastFailureAt().toString());
        }
        return b.build();
    }
}
