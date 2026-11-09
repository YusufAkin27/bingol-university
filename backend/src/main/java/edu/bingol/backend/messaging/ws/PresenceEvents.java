package edu.bingol.backend.messaging.ws;

import jakarta.annotation.PreDestroy;
import java.security.Principal;
import java.time.Instant;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.user.SimpUser;
import org.springframework.messaging.simp.user.SimpUserRegistry;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

/**
 * WebSocket oturum olaylarini cevrimici durumuna cevirir.
 * Kopus {@link #GRACE_MS} kadar ertelenir: istemci belirteci yenilerken (yaklasik 14 dk'da bir) eski oturumu kapatip
 * hemen yenisini acar; ertelenmeseydi "cevrimdisi + son gorulme" kisa sure yanip sonerdi. Erteleme bitince
 * kullanicinin bu sunucuda HICBIR oturumu yoksa cevrimdisi yazilir (cok cihaz: biri acik kaldikca cevrimici).
 */
@Component
public class PresenceEvents {

    /** Kopustan sonra cevrimdisi yazmadan once beklenen sure. */
    static final long GRACE_MS = 3_000;

    private final PresenceService presence;
    private final SimpUserRegistry registry;
    private final long graceMs;
    private final ScheduledExecutorService timer;

    @Autowired
    public PresenceEvents(PresenceService presence, SimpUserRegistry registry) {
        this(presence, registry, GRACE_MS);
    }

    /** {@code graceMs <= 0}: erteleme yok (testler). */
    PresenceEvents(PresenceService presence, SimpUserRegistry registry, long graceMs) {
        this.presence = presence;
        this.registry = registry;
        this.graceMs = graceMs;
        this.timer = graceMs > 0
                ? Executors.newSingleThreadScheduledExecutor(r -> {
                    Thread t = new Thread(r, "presence-grace");
                    t.setDaemon(true);
                    return t;
                })
                : null;
    }

    @PreDestroy
    void shutdown() {
        if (timer != null) {
            timer.shutdownNow();
        }
    }

    @EventListener
    public void connected(SessionConnectedEvent e) {
        userId(e.getUser()).ifPresent(presence::markOnline);
    }

    /** Kullanicinin bu sunucuda baska oturumu kalmadiysa cevrimdisi yazilir (baska sunucudaysa heartbeat 10 sn'de yeniler). */
    @EventListener
    public void disconnected(SessionDisconnectEvent e) {
        String sessionId = e.getSessionId();
        userId(e.getUser()).ifPresent(id -> {
            if (hasOtherSession(id, sessionId)) {
                return;
            }
            Instant at = Instant.now();
            if (timer == null) {
                presence.markOffline(id, at);
            } else {
                timer.schedule(() -> offlineIfGone(id, sessionId, at), graceMs, TimeUnit.MILLISECONDS);
            }
        });
    }

    private void offlineIfGone(Long id, String closedSessionId, Instant at) {
        try {
            if (!hasOtherSession(id, closedSessionId)) {
                presence.markOffline(id, at);
            }
        } catch (RuntimeException ex) {
            // en iyi caba: anahtar zaten 30 sn TTL ile duser
        }
    }

    private boolean hasOtherSession(Long id, String closedSessionId) {
        SimpUser u = registry.getUser(String.valueOf(id));
        return u != null && u.getSessions().stream().anyMatch(s -> !s.getId().equals(closedSessionId));
    }

    private static java.util.Optional<Long> userId(Principal p) {
        try {
            return p == null ? java.util.Optional.empty() : java.util.Optional.of(Long.valueOf(p.getName()));
        } catch (NumberFormatException ex) {
            return java.util.Optional.empty();
        }
    }
}
