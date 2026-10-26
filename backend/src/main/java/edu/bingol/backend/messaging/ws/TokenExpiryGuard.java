package edu.bingol.backend.messaging.ws;

import edu.bingol.backend.auth.token.SessionsRevokedEvent;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.WebSocketHandlerDecorator;

/**
 * Suresi dolan access token'a bagli WebSocket oturumlarini sunucudan kapatir: aksi halde acik baglanti abonelik
 * teslimini token bittikten sonra da surdururdu. Bitis zamani CONNECT'te {@link StompAuthInterceptor} tarafindan
 * oturum niteliklerine yazilir (exp + tolerans). Istemci yeni token ile yeniden baglanir ve `after=` ile bosluklari ceker.
 */
@Component
public class TokenExpiryGuard {

    static final CloseStatus EXPIRED = new CloseStatus(CloseStatus.POLICY_VIOLATION.getCode(), "TOKEN_EXPIRED");

    private static final Logger log = LoggerFactory.getLogger(TokenExpiryGuard.class);

    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();

    /** WebSocketConfig'te tasima katmanina eklenir; oturumlari kayda alir/siler. */
    public WebSocketHandler decorate(WebSocketHandler handler) {
        return new WebSocketHandlerDecorator(handler) {
            @Override
            public void afterConnectionEstablished(WebSocketSession session) throws Exception {
                sessions.put(session.getId(), session);
                super.afterConnectionEstablished(session);
            }

            @Override
            public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
                sessions.remove(session.getId());
                super.afterConnectionClosed(session, status);
            }
        };
    }

    static final CloseStatus REVOKED = new CloseStatus(CloseStatus.POLICY_VIOLATION.getCode(), "SESSION_REVOKED");

    /** Tum oturumlar iptal edilince (logout-all, sifre sifirlama) kullanicinin acik WS baglantilarini kapatir. */
    @EventListener
    public void onSessionsRevoked(SessionsRevokedEvent e) {
        closeUser(e.userId());
    }

    int closeUser(Long userId) {
        int closed = 0;
        for (WebSocketSession s : sessions.values()) {
            if (userId != null && userId.equals(s.getAttributes().get(StompAuthInterceptor.USER_ID_ATTR))) {
                sessions.remove(s.getId());
                try {
                    s.close(REVOKED);
                    closed++;
                } catch (Exception ex) {
                    log.debug("Iptal edilen WS oturumu kapatilamadi: {}", ex.toString());
                }
            }
        }
        return closed;
    }

    @Scheduled(fixedDelay = 30_000)
    void sweep() {
        sweep(Instant.now().getEpochSecond());
    }

    /** `nowEpochSeconds` > exp + tolerans olan oturumlari kapatir; kapatilan sayiyi doner. */
    int sweep(long nowEpochSeconds) {
        int closed = 0;
        for (WebSocketSession s : sessions.values()) {
            Object exp = s.getAttributes().get(StompAuthInterceptor.TOKEN_EXP_ATTR);
            if (exp instanceof Long e && nowEpochSeconds > e + StompAuthInterceptor.EXP_GRACE_SECONDS) {
                sessions.remove(s.getId());
                try {
                    s.close(EXPIRED);
                    closed++;
                } catch (Exception ex) {
                    log.debug("Suresi dolan WS oturumu kapatilamadi: {}", ex.toString());
                }
            }
        }
        return closed;
    }
}
