package edu.bingol.backend.messaging.ws;

import edu.bingol.backend.accessban.AccessGuard;
import edu.bingol.backend.accessban.ClientContext;
import edu.bingol.backend.accessban.ClientContexts;
import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessagingException;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.stereotype.Component;

/**
 * STOMP kanal guvenligi. /ws el sikismasi herkese aciktir; kimlik CONNECT cercevesinde (Authorization: Bearer) zorunludur.
 * <ul>
 *   <li>CONNECT: JWT gecerli ve hesap askida degil; yoksa ERROR cercevesi (baglanti kurulmaz)</li>
 *   <li>SEND: yalnizca /app/** ; token suresi dolduysa (60 sn tolerans) ya da hesap askiya alindiysa reddedilir,
 *       istemci yeni token ile yeniden baglanmalidir</li>
 *   <li>SUBSCRIBE: yalnizca /user/queue/{messages,read-receipts,typing,message-events,errors}; /topic/** ve digerleri kapali</li>
 * </ul>
 */
@Component
public class StompAuthInterceptor implements ChannelInterceptor {

    static final String TOKEN_EXP_ATTR = "tokenExp";
    static final String USER_ID_ATTR = "wsUserId";
    static final String CLIENT_ATTR = "wsClient";
    /** El sikisma aninda yazilan {@link ClientContext} (IP + X-Device-Id ozeti). */
    public static final String CONTEXT_ATTR = "wsClientContext";
    static final long EXP_GRACE_SECONDS = 60;
    static final Set<String> SUBSCRIBABLE = Set.of("/user/queue/messages", "/user/queue/read-receipts",
            "/user/queue/typing", "/user/queue/errors", "/user/queue/message-events");

    private static final Pattern EXP = Pattern.compile("\"exp\"\\s*:\\s*(\\d+)");

    private final JwtService jwt;
    private final StringRedisTemplate redis;

    private AccessGuard accessGuard;
    private ClientContexts contexts;

    /** Kullanici basina saniyede en cok SEND cercevesi (asan cerceveler sessizce atilir; 5 kati asilirsa baglanti kapanir). */
    @Value("${app.ws.max-frames-per-second:20}")
    private int maxFramesPerSecond = 20;
    private final java.util.concurrent.ConcurrentHashMap<Long, long[]> frameWindows = new java.util.concurrent.ConcurrentHashMap<>();

    private java.util.function.LongSupplier nowMillis = System::currentTimeMillis;

    void setMaxFramesPerSecond(int n) {
        this.maxFramesPerSecond = n;
    }

    /** Test icin saat. */
    void setNowMillis(java.util.function.LongSupplier nowMillis) {
        this.nowMillis = nowMillis;
    }

    /** Bu saniyede bu kullanicinin kacinci cercevesi; bellek ici (Redis gidis-donusu yok), ornek basina. */
    private long frameCount(Long uid) {
        long sec = nowMillis.getAsLong() / 1000;
        if (frameWindows.size() > 50_000) {
            frameWindows.clear();
        }
        long[] w = frameWindows.compute(uid, (k, cur) -> {
            if (cur == null || cur[0] != sec) {
                return new long[] {sec, 1};
            }
            cur[1]++;
            return cur;
        });
        return w[1];
    }

    public StompAuthInterceptor(JwtService jwt, StringRedisTemplate redis) {
        this.jwt = jwt;
        this.redis = redis;
    }

    /** Erisim engeli (opsiyonel baglanti: testlerde kurulmaz). */
    @Autowired(required = false)
    void setAccessControls(AccessGuard guard, ClientContexts contexts) {
        this.accessGuard = guard;
        this.contexts = contexts;
    }

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor acc = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        StompCommand cmd = acc == null ? null : acc.getCommand();
        if (cmd == null) {
            return message;
        }
        switch (cmd) {
            case CONNECT, STOMP -> connect(acc);
            case SEND -> {
                Long uid = requireUser(acc);
                String dest = acc.getDestination();
                if (dest == null || !dest.startsWith("/app/")) {
                    throw new Rejected("FORBIDDEN_DESTINATION");
                }
                Long exp = acc.getSessionAttributes() == null ? null : (Long) acc.getSessionAttributes().get(TOKEN_EXP_ATTR);
                if (exp == null || Instant.now().getEpochSecond() > exp + EXP_GRACE_SECONDS) {
                    throw new Rejected("TOKEN_EXPIRED");
                }
                // Cerceve hiz siniri Redis/DB'den ONCE: sinir asilirsa cerceve atilir, asiri ise baglanti kapatilir
                if (maxFramesPerSecond > 0) {
                    long n = frameCount(uid);
                    if (n > (long) maxFramesPerSecond * 5) {
                        throw new Rejected("RATE_LIMITED");
                    }
                    if (n > maxFramesPerSecond) {
                        return null;
                    }
                }
                if (Boolean.TRUE.equals(redis.hasKey(JwtAuthFilter.SUSPENDED_KEY_PREFIX + uid))) {
                    throw new Rejected("SUSPENDED");
                }
            }
            case SUBSCRIBE -> {
                requireUser(acc);
                if (!SUBSCRIBABLE.contains(acc.getDestination())) {
                    throw new Rejected("FORBIDDEN_DESTINATION");
                }
            }
            default -> {
                // DISCONNECT, UNSUBSCRIBE, ACK vb. serbest; yetkisiz kullanici icin de zararsizdir
            }
        }
        return message;
    }

    private void connect(StompHeaderAccessor acc) {
        String h = acc.getFirstNativeHeader("Authorization");
        JwtService.Identity id = h != null && h.startsWith("Bearer ") ? jwt.parse(h.substring(7).trim()) : null;
        if (id == null) {
            throw new Rejected("UNAUTHORIZED");
        }
        if (Boolean.TRUE.equals(redis.hasKey(JwtAuthFilter.SUSPENDED_KEY_PREFIX + id.userId()))) {
            throw new Rejected("SUSPENDED");
        }
        checkAccess(acc, id.userId());
        var ops = redis.opsForValue();
        String revokedAt = ops == null ? null : ops.get(JwtAuthFilter.PASSWORD_CHANGED_KEY_PREFIX + id.userId());
        if (JwtAuthFilter.tokenRevoked(id.issuedAtMillis(), revokedAt)) {
            throw new Rejected("SESSION_REPLACED");
        }
        if ("mobile".equals(id.client()) && ops != null && JwtAuthFilter.tokenRevoked(id.issuedAtMillis(),
                ops.get(JwtAuthFilter.MOBILE_REVOKED_KEY_PREFIX + id.userId()))) {
            throw new Rejected("SESSION_REPLACED");
        }
        // jwt.parse imzayi dogruladi; bitis zamanini yuk kisminden okuruz (JwtService'e dokunmadan).
        long exp = expOf(h.substring(7).trim());
        if (Instant.now().getEpochSecond() > exp) {
            throw new Rejected("TOKEN_EXPIRED");
        }
        // Principal adi = kullanici id'si; convertAndSendToUser hedefi bununla eslesir.
        acc.setUser(new UsernamePasswordAuthenticationToken(id.userId(), null,
                List.of(new SimpleGrantedAuthority("ROLE_" + id.role().name()))));
        if (acc.getSessionAttributes() != null) {
            acc.getSessionAttributes().put(TOKEN_EXP_ATTR, exp);
            acc.getSessionAttributes().put(USER_ID_ATTR, id.userId());
            acc.getSessionAttributes().put(CLIENT_ATTR, id.client());
        }
    }

    /** CONNECT'te cihaz (`device-id` basligi ya da el sikisma basligi), IP ve kullanici engeli. */
    private void checkAccess(StompHeaderAccessor acc, Long userId) {
        if (accessGuard == null || contexts == null) {
            return;
        }
        ClientContext ctx = acc.getSessionAttributes() == null ? null
                : (ClientContext) acc.getSessionAttributes().get(CONTEXT_ATTR);
        String raw = acc.getFirstNativeHeader("device-id");
        if (raw != null) {
            ctx = contexts.build(ctx == null ? null : ctx.ip(), raw, acc.getFirstNativeHeader("device-platform"),
                    acc.getFirstNativeHeader("app-version"));
        }
        if (ctx != null && accessGuard.blocked(ctx, userId, "/ws") != null) {
            throw new Rejected("ACCESS_BLOCKED");
        }
    }

    private static Long requireUser(StompHeaderAccessor acc) {
        if (acc.getUser() == null) {
            throw new Rejected("UNAUTHORIZED");
        }
        try {
            return Long.valueOf(acc.getUser().getName());
        } catch (NumberFormatException e) {
            throw new Rejected("UNAUTHORIZED");
        }
    }

    /** JWT yukunden `exp` (saniye); okunamazsa 0 (= suresi dolmus sayilir). */
    static long expOf(String token) {
        try {
            String payload = new String(Base64.getUrlDecoder().decode(token.split("\\.")[1]), StandardCharsets.UTF_8);
            Matcher m = EXP.matcher(payload);
            return m.find() ? Long.parseLong(m.group(1)) : 0;
        } catch (RuntimeException e) {
            return 0;
        }
    }

    /** Mesaj `message` basligi olarak ERROR cercevesinde istemciye gider (kod: UNAUTHORIZED, TOKEN_EXPIRED, ...). */
    static class Rejected extends MessagingException {
        Rejected(String code) {
            super(code);
        }
    }
}
