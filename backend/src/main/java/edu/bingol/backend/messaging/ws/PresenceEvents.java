package edu.bingol.backend.messaging.ws;

import java.security.Principal;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.user.SimpUser;
import org.springframework.messaging.simp.user.SimpUserRegistry;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

/** WebSocket oturum olaylarini cevrimici durumuna cevirir. */
@Component
public class PresenceEvents {

    private final PresenceService presence;
    private final SimpUserRegistry registry;

    public PresenceEvents(PresenceService presence, SimpUserRegistry registry) {
        this.presence = presence;
        this.registry = registry;
    }

    @EventListener
    public void connected(SessionConnectedEvent e) {
        userId(e.getUser()).ifPresent(presence::markOnline);
    }

    /** Kullanicinin bu sunucuda baska oturumu kalmadiysa cevrimdisi yazilir (baska sunucudaysa heartbeat 10 sn'de yeniler). */
    @EventListener
    public void disconnected(SessionDisconnectEvent e) {
        userId(e.getUser()).ifPresent(id -> {
            SimpUser u = registry.getUser(String.valueOf(id));
            boolean other = u != null && u.getSessions().stream().anyMatch(s -> !s.getId().equals(e.getSessionId()));
            if (!other) {
                presence.markOffline(id);
            }
        });
    }

    private static java.util.Optional<Long> userId(Principal p) {
        try {
            return p == null ? java.util.Optional.empty() : java.util.Optional.of(Long.valueOf(p.getName()));
        } catch (NumberFormatException ex) {
            return java.util.Optional.empty();
        }
    }
}
