package edu.bingol.backend.mail;

import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.boot.health.contributor.Status;
import org.springframework.stereotype.Component;

/**
 * Kuyruk birikmesi uyarisi. Ozel "WARN" durumu toplam sagligi DOWN yapmaz (HTTP 200 kalir); yalnizca
 * ayrintida gorunur.
 */
@Component("mailQueue")
public class MailQueueHealthIndicator implements HealthIndicator {

    static final long BACKLOG_WARN_THRESHOLD = 100;
    private static final Status WARN = new Status("WARN");

    /** Sayimlar 30 sn onbelleklenir: compose healthcheck her 15 sn'de cagirir. */
    private static final long CACHE_MS = 30_000;

    private final MailService mail;
    private volatile long cachedAt;
    private volatile Health cached;

    public MailQueueHealthIndicator(MailService mail) {
        this.mail = mail;
    }

    @Override
    public Health health() {
        long now = System.currentTimeMillis();
        Health c = cached;
        if (c != null && now - cachedAt < CACHE_MS) {
            return c;
        }
        MailService.HealthStats s = mail.healthStats();
        long backlog = s.pending() + s.failed();
        Health.Builder b = (s.dead() > 0 || backlog > BACKLOG_WARN_THRESHOLD) ? Health.status(WARN) : Health.up();
        Health h = b.withDetail("pending", s.pending()).withDetail("failed", s.failed())
                .withDetail("dead", s.dead()).build();
        cached = h;
        cachedAt = now;
        return h;
    }
}
