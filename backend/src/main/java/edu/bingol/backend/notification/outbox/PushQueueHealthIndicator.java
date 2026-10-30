package edu.bingol.backend.notification.outbox;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.boot.health.contributor.Status;
import org.springframework.stereotype.Component;

/**
 * /actuator/health -> pushQueue. Olu kayit ya da 15 dk'dan eski bekleyen varsa ozel "WARN" durumu (toplam sagligi
 * DOWN yapmaz; yalnizca ayrintida gorunur).
 */
@Component("pushQueue")
@ConditionalOnProperty(name = "app.push.outbox.enabled", havingValue = "true", matchIfMissing = true)
public class PushQueueHealthIndicator implements HealthIndicator {

    static final long STALE_SECONDS = 15 * 60;
    private static final Status WARN = new Status("WARN");

    private final PushOutboxService outbox;
    private final org.springframework.beans.factory.ObjectProvider<PushOutboxWorker> worker;

    public PushQueueHealthIndicator(PushOutboxService outbox,
                                    org.springframework.beans.factory.ObjectProvider<PushOutboxWorker> worker) {
        this.outbox = outbox;
        this.worker = worker;
    }

    @Override
    public Health health() {
        PushOutboxService.Stats s = outbox.stats();
        boolean stale = s.oldestPendingAgeSeconds() != null && s.oldestPendingAgeSeconds() > STALE_SECONDS && s.enabled();
        Health.Builder b = (s.dead() > 0 || stale) ? Health.status(WARN) : Health.up();
        b.withDetail("pending", s.pending() + s.failed()).withDetail("sending", s.sending()).withDetail("dead", s.dead());
        if (s.oldestPendingAgeSeconds() != null) {
            b.withDetail("oldestPendingAgeSeconds", s.oldestPendingAgeSeconds());
        }
        PushOutboxWorker w = worker.getIfAvailable();
        if (w != null && !w.errorCodeCounts().isEmpty()) {
            // Surec basindan beri FCM hata kodlari (ornek THIRD_PARTY_AUTH_ERROR = APNs anahtari eksik/yanlis)
            b.withDetail("errorCodes", w.errorCodeCounts());
        }
        return b.build();
    }
}
