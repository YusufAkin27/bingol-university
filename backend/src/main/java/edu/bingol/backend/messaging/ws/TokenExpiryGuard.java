package edu.bingol.backend.messaging.ws;

import edu.bingol.backend.accessban.AccessBlockedEvent;
import edu.bingol.backend.auth.token.SessionsRevokedEvent;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Lazy;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.simp.SimpMessageType;
import org.springframework.messaging.simp.SimpMessagingTemplate;
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

    /** /user/queue/message-events: type = "session-replaced" (oturum baska cihaz girisiyle/iptalle sonlandi). */
    public record SessionReplacedEvent(String type, String at) {}

    static final CloseStatus BLOCKED = new CloseStatus(CloseStatus.POLICY_VIOLATION.getCode(), "ACCESS_BLOCKED");

    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();
    private final SimpMessagingTemplate template;
    private final long closeDelayMs;
    private final ScheduledExecutorService closer;

    /**
     * `closeDelayMs`: olay gonderildikten sonra baglantinin kapatilmasina taninan sure (olay broker kanalindan
     * asenkron akar; hemen kapatmak istemcinin olayi almasini yarisa sokardi). 0 = hemen kapat (testler).
     */
    @Autowired
    public TokenExpiryGuard(@Lazy SimpMessagingTemplate template,
                            @Value("${app.session.close-delay-ms:400}") long closeDelayMs) {
        this.template = template;
        this.closeDelayMs = closeDelayMs;
        this.closer = closeDelayMs > 0 ? Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "ws-session-closer");
            t.setDaemon(true);
            return t;
        }) : null;
    }

    public TokenExpiryGuard() {
        this(null, 0);
    }

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

    static final CloseStatus REVOKED = new CloseStatus(CloseStatus.POLICY_VIOLATION.getCode(), "SESSION_REPLACED");

    /**
     * Oturumlar iptal edilince (baska cihaz girisi, logout-all, sifre sifirlama) kullanicinin etkilenen acik WS
     * baglantilarina once `session-replaced` olayi gider, sonra baglanti kapatilir. Etkilenen oturumlar olay
     * aninda sabitlenir: sonradan baglanan yeni cihaz oturumu kapatilmaz.
     */
    @EventListener
    public void onSessionsRevoked(SessionsRevokedEvent e) {
        closeUser(e.userId(), e.client());
    }

    /**
     * Erisim engeli: kullanicinin tum WS baglantilarina `access-blocked` olayi (message-events) gider, sonra
     * ACCESS_BLOCKED koduyla kapanir (SESSION_REPLACED yerine; istemci cikis yapip engel ekranini gosterir).
     */
    @EventListener
    public void onAccessBlocked(AccessBlockedEvent e) {
        closeUser(e.userId(), null, true);
    }

    int closeUser(Long userId, String client) {
        return closeUser(userId, client, false);
    }

    int closeUser(Long userId, String client, boolean blocked) {
        List<WebSocketSession> targets = new ArrayList<>();
        for (WebSocketSession s : sessions.values()) {
            Map<String, Object> a = s.getAttributes();
            boolean mine = userId != null && userId.equals(a.get(StompAuthInterceptor.USER_ID_ATTR));
            // client null = hepsi; aksi halde yalniz o istemci turu (niteliksiz eski oturum = web)
            Object c = a.get(StompAuthInterceptor.CLIENT_ATTR);
            if (mine && (client == null || client.equals(c == null ? "web" : c))) {
                sessions.remove(s.getId());
                targets.add(s);
            }
        }
        for (WebSocketSession s : targets) {
            notifyReplaced(userId, s, blocked ? "access-blocked" : "session-replaced");
        }
        CloseStatus status = blocked ? BLOCKED : REVOKED;
        if (closeDelayMs > 0 && !targets.isEmpty()) {
            closer.schedule(() -> targets.forEach(s -> closeQuietly(s, status)), closeDelayMs, TimeUnit.MILLISECONDS);
        } else {
            targets.forEach(s -> closeQuietly(s, status));
        }
        return targets.size();
    }

    /** Yalnizca hedef WS oturumuna gonderilir (simpSessionId); hata baglanti kapatmayi engellemez. */
    private void notifyReplaced(Long userId, WebSocketSession s, String type) {
        if (template == null) {
            return;
        }
        try {
            SimpMessageHeaderAccessor h = SimpMessageHeaderAccessor.create(SimpMessageType.MESSAGE);
            h.setSessionId(s.getId());
            h.setLeaveMutable(true);
            template.convertAndSendToUser(String.valueOf(userId), "/queue/message-events",
                    new SessionReplacedEvent(type, Instant.now().toString()), h.getMessageHeaders());
        } catch (RuntimeException ex) {
            log.debug("session-replaced olayi gonderilemedi: {}", ex.toString());
        }
    }

    private void closeQuietly(WebSocketSession s, CloseStatus status) {
        try {
            s.close(status);
        } catch (Exception ex) {
            log.debug("Iptal edilen WS oturumu kapatilamadi: {}", ex.toString());
        }
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
