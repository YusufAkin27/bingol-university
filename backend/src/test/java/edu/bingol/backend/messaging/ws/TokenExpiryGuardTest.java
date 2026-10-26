package edu.bingol.backend.messaging.ws;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
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
}
