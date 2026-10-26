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

    private final MailService mail;

    public MailQueueHealthIndicator(MailService mail) {
        this.mail = mail;
    }

    @Override
    public Health health() {
        MailService.QueueStats s = mail.queueStats();
        long backlog = s.pending() + s.failed();
        Health.Builder b = (s.dead() > 0 || backlog > BACKLOG_WARN_THRESHOLD) ? Health.status(WARN) : Health.up();
        return b.withDetail("pending", s.pending()).withDetail("failed", s.failed())
                .withDetail("dead", s.dead()).build();
    }
}
