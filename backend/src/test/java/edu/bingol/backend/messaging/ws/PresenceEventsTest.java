package edu.bingol.backend.messaging.ws;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.security.Principal;
import java.time.Instant;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.user.SimpSession;
import org.springframework.messaging.simp.user.SimpUser;
import org.springframework.messaging.simp.user.SimpUserRegistry;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

/** Cevrimici/cevrimdisi: cok oturum, kopus ertelemesi (belirtec yenilemede yanip sonme yok). */
class PresenceEventsTest {

    private static SimpSession session(String id) {
        SimpSession s = mock(SimpSession.class);
        when(s.getId()).thenReturn(id);
        return s;
    }

    private static SimpUser user(SimpSession... sessions) {
        SimpUser u = mock(SimpUser.class);
        Set<SimpSession> set = Set.of(sessions);
        when(u.getSessions()).thenReturn(set);
        return u;
    }

    private static SessionDisconnectEvent disconnect(String sessionId, long uid) {
        Principal p = () -> String.valueOf(uid);
        return new SessionDisconnectEvent(new Object(), org.springframework.messaging.support.MessageBuilder
                .withPayload(new byte[0]).setHeader("simpSessionId", sessionId).build(), sessionId, CloseStatus.NORMAL, p);
    }

    @Test
    void otherDeviceStillConnectedKeepsUserOnline() {
        PresenceService presence = mock(PresenceService.class);
        SimpUserRegistry registry = mock(SimpUserRegistry.class);
        SimpUser both = user(session("A"), session("B"));
        when(registry.getUser("7")).thenReturn(both);
        PresenceEvents ev = new PresenceEvents(presence, registry, 0);

        ev.disconnected(disconnect("A", 7));

        verify(presence, never()).markOffline(any(), any());
    }

    @Test
    void lastSessionClosedMarksOfflineWithDisconnectTime() {
        PresenceService presence = mock(PresenceService.class);
        SimpUserRegistry registry = mock(SimpUserRegistry.class);
        SimpUser onlyA = user(session("A"));
        when(registry.getUser("7")).thenReturn(onlyA);
        PresenceEvents ev = new PresenceEvents(presence, registry, 0);

        ev.disconnected(disconnect("A", 7));

        verify(presence).markOffline(eq(7L), any(Instant.class));
    }

    @Test
    void reconnectWithinGraceDoesNotFlipToOffline() throws Exception {
        PresenceService presence = mock(PresenceService.class);
        SimpUserRegistry registry = mock(SimpUserRegistry.class);
        // Belirtec yenileme: eski oturum (A) kapanir, yenisi (B) kopus ertelemesi bitmeden kaydolur.
        SimpUser oldOne = user(session("A"));
        SimpUser newOne = user(session("B"));
        when(registry.getUser("7")).thenReturn(oldOne, newOne);
        PresenceEvents ev = new PresenceEvents(presence, registry, 150);

        ev.disconnected(disconnect("A", 7));
        Thread.sleep(400);

        verify(presence, never()).markOffline(any(), any());
        ev.shutdown();
    }

    @Test
    void noReconnectAfterGraceMarksOffline() {
        PresenceService presence = mock(PresenceService.class);
        SimpUserRegistry registry = mock(SimpUserRegistry.class);
        when(registry.getUser("7")).thenReturn(null);
        PresenceEvents ev = new PresenceEvents(presence, registry, 100);

        ev.disconnected(disconnect("A", 7));

        verify(presence, timeout(2000)).markOffline(eq(7L), any(Instant.class));
        ev.shutdown();
    }

}
