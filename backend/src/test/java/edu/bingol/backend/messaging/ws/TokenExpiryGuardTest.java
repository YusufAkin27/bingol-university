package edu.bingol.backend.messaging.ws;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.token.SessionsRevokedEvent;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.WebSocketSession;

class TokenExpiryGuardTest {

    private final TokenExpiryGuard guard = new TokenExpiryGuard();

    private WebSocketSession connect(String id, Long exp) throws Exception {
        WebSocketSession s = mock(WebSocketSession.class);
        Map<String, Object> attrs = new HashMap<>();
        if (exp != null) {
            attrs.put(StompAuthInterceptor.TOKEN_EXP_ATTR, exp);
        }
        when(s.getId()).thenReturn(id);
        when(s.getAttributes()).thenReturn(attrs);
        guard.decorate(mock(WebSocketHandler.class)).afterConnectionEstablished(s);
        return s;
    }

    @Test
    void closesOnlySessionsPastExpiryPlusGrace() throws Exception {
        long now = 10_000;
        WebSocketSession expired = connect("a", now - StompAuthInterceptor.EXP_GRACE_SECONDS - 1);
        WebSocketSession withinGrace = connect("b", now - 10);
        WebSocketSession valid = connect("c", now + 600);
        WebSocketSession noToken = connect("d", null);

        assertEquals(1, guard.sweep(now));

        verify(expired).close(TokenExpiryGuard.EXPIRED);
        verify(withinGrace, never()).close(any(CloseStatus.class));
        verify(valid, never()).close(any(CloseStatus.class));
        verify(noToken, never()).close(any(CloseStatus.class));
    }

    @Test
    void closedSessionIsForgotten() throws Exception {
        WebSocketSession s = connect("a", 1L);
        guard.decorate(mock(WebSocketHandler.class)).afterConnectionClosed(s, CloseStatus.NORMAL);

        assertEquals(0, guard.sweep(1_000_000));
    }

    @Test
    void revokedUserSessionsAreClosed() throws Exception {
        WebSocketSession mine = connect("a", 99_999L);
        mine.getAttributes().put(StompAuthInterceptor.USER_ID_ATTR, 7L);
        WebSocketSession other = connect("b", 99_999L);
        other.getAttributes().put(StompAuthInterceptor.USER_ID_ATTR, 8L);

        guard.onSessionsRevoked(new edu.bingol.backend.auth.token.SessionsRevokedEvent(7L));

        verify(mine).close(TokenExpiryGuard.REVOKED);
        verify(other, never()).close(any(CloseStatus.class));
    }

    private WebSocketSession connectClient(String id, long uid, String client) throws Exception {
        WebSocketSession s = connect(id, 99_999L);
        s.getAttributes().put(StompAuthInterceptor.USER_ID_ATTR, uid);
        s.getAttributes().put(StompAuthInterceptor.CLIENT_ATTR, client);
        return s;
    }

    @Test
    void mobileRevokeSendsEventBeforeCloseAndSkipsWebSessions() throws Exception {
        SimpMessagingTemplate template = mock(SimpMessagingTemplate.class);
        TokenExpiryGuard g = new TokenExpiryGuard(template, 0);
        WebSocketSession mobile = mock(WebSocketSession.class);
        WebSocketSession web = mock(WebSocketSession.class);
        for (var e : Map.of("m", mobile, "w", web).entrySet()) {
            Map<String, Object> attrs = new HashMap<>();
            attrs.put(StompAuthInterceptor.USER_ID_ATTR, 7L);
            attrs.put(StompAuthInterceptor.CLIENT_ATTR, e.getKey().equals("m") ? "mobile" : "web");
            when(e.getValue().getId()).thenReturn(e.getKey());
            when(e.getValue().getAttributes()).thenReturn(attrs);
            g.decorate(mock(WebSocketHandler.class)).afterConnectionEstablished(e.getValue());
        }

        g.onSessionsRevoked(new SessionsRevokedEvent(7L, "mobile", true, true));

        InOrder order = inOrder(template, mobile);
        order.verify(template).convertAndSendToUser(eq("7"), eq("/queue/message-events"),
                any(TokenExpiryGuard.SessionReplacedEvent.class), anyMap());
        order.verify(mobile).close(TokenExpiryGuard.REVOKED);
        verify(web, never()).close(any(CloseStatus.class));
        assertEquals("SESSION_REPLACED", TokenExpiryGuard.REVOKED.getReason());
    }

    @Test
    void revokeAllClosesBothClients() throws Exception {
        WebSocketSession mobile = connectClient("m", 7L, "mobile");
        WebSocketSession web = connectClient("w", 7L, "web");

        guard.onSessionsRevoked(new SessionsRevokedEvent(7L));

        verify(mobile).close(TokenExpiryGuard.REVOKED);
        verify(web).close(TokenExpiryGuard.REVOKED);
    }
}
