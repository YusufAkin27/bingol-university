package edu.bingol.backend.messaging.ws;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.user.Role;
import edu.bingol.backend.user.User;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;

class StompAuthInterceptorTest {

    private static final String SECRET = "test-secret-test-secret-test-secret-1234";

    private final JwtService jwt = new JwtService(new JwtProperties(SECRET, 15, 30));
    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    private final MessageChannel channel = mock(MessageChannel.class);
    private final StompAuthInterceptor interceptor = new StompAuthInterceptor(jwt, redis);

    private String token(long userId) {
        User u = new User();
        u.setId(userId);
        u.setEmail("a@bingol.edu.tr");
        return jwt.createAccessToken(u);
    }

    private static Message<byte[]> frame(StompCommand cmd, String dest, String auth, Map<String, Object> session,
                                         java.security.Principal user) {
        StompHeaderAccessor acc = StompHeaderAccessor.create(cmd);
        if (dest != null) {
            acc.setDestination(dest);
        }
        if (auth != null) {
            acc.setNativeHeader("Authorization", auth);
        }
        acc.setSessionAttributes(session);
        acc.setUser(user);
        acc.setLeaveMutable(true);
        return MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());
    }

    @Test
    void connectWithoutOrWithBadTokenIsRejected() {
        for (String auth : new String[] {null, "Bearer", "Bearer abc.def.ghi", "Basic xyz"}) {
            var e = assertThrows(StompAuthInterceptor.Rejected.class,
                    () -> interceptor.preSend(frame(StompCommand.CONNECT, null, auth, new HashMap<>(), null), channel));
            assertEquals("UNAUTHORIZED", e.getMessage());
        }
    }

    @Test
    void connectWithExpiredTokenIsRejected() {
        String expired = Jwts.builder().subject("5").claim("role", "USER")
                .expiration(new Date(System.currentTimeMillis() - 60_000))
                .signWith(Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8))).compact();

        assertThrows(StompAuthInterceptor.Rejected.class, () -> interceptor.preSend(
                frame(StompCommand.CONNECT, null, "Bearer " + expired, new HashMap<>(), null), channel));
    }

    @Test
    void suspendedUserCannotConnect() {
        when(redis.hasKey(JwtAuthFilter.SUSPENDED_KEY_PREFIX + 5L)).thenReturn(true);

        var e = assertThrows(StompAuthInterceptor.Rejected.class, () -> interceptor.preSend(
                frame(StompCommand.CONNECT, null, "Bearer " + token(5), new HashMap<>(), null), channel));
        assertEquals("SUSPENDED", e.getMessage());
    }

    @Test
    void validConnectSetsPrincipalNamedByUserIdAndTokenExpiry() {
        Map<String, Object> session = new HashMap<>();
        Message<?> out = interceptor.preSend(frame(StompCommand.CONNECT, null, "Bearer " + token(5), session, null), channel);

        assertEquals("5", StompHeaderAccessor.wrap(out).getUser().getName());
        assertNotNull(session.get("tokenExp"));
        assertEquals(true, (Long) session.get("tokenExp") > Instant.now().getEpochSecond());
    }

    @Test
    void sendRequiresAuthenticatedUserAndAppDestination() {
        var anon = frame(StompCommand.SEND, "/app/chat.send", null, new HashMap<>(), null);
        assertThrows(StompAuthInterceptor.Rejected.class, () -> interceptor.preSend(anon, channel));

        java.security.Principal user = () -> "5";
        Map<String, Object> session = new HashMap<>(Map.of("tokenExp", Instant.now().getEpochSecond() + 600));
        var other = frame(StompCommand.SEND, "/queue/messages", null, session, user);
        assertThrows(StompAuthInterceptor.Rejected.class, () -> interceptor.preSend(other, channel));
        var userQueue = frame(StompCommand.SEND, "/user/queue/messages", null, session, user);
        assertThrows(StompAuthInterceptor.Rejected.class, () -> interceptor.preSend(userQueue, channel));

        interceptor.preSend(frame(StompCommand.SEND, "/app/chat.send", null, session, user), channel);
    }

    @Test
    void sendAfterTokenExpiryPlusGraceIsRejected() {
        java.security.Principal user = () -> "5";
        long now = Instant.now().getEpochSecond();

        // 30 sn once bitti: 60 sn tolerans icinde
        interceptor.preSend(frame(StompCommand.SEND, "/app/chat.send", null,
                new HashMap<>(Map.of("tokenExp", now - 30)), user), channel);

        var e = assertThrows(StompAuthInterceptor.Rejected.class, () -> interceptor.preSend(
                frame(StompCommand.SEND, "/app/chat.send", null, new HashMap<>(Map.of("tokenExp", now - 120)), user), channel));
        assertEquals("TOKEN_EXPIRED", e.getMessage());
    }

    @Test
    void subscribeIsLimitedToUserQueuesAndTopicsAreClosed() {
        java.security.Principal user = () -> "5";
        interceptor.preSend(frame(StompCommand.SUBSCRIBE, "/user/queue/messages", null, new HashMap<>(), user), channel);
        interceptor.preSend(frame(StompCommand.SUBSCRIBE, "/user/queue/read-receipts", null, new HashMap<>(), user), channel);

        for (String dest : new String[] {"/topic/chat", "/queue/messages", "/user/7/queue/messages", "/user/queue/other"}) {
            assertThrows(StompAuthInterceptor.Rejected.class, () -> interceptor.preSend(
                    frame(StompCommand.SUBSCRIBE, dest, null, new HashMap<>(), user), channel));
        }
        assertThrows(StompAuthInterceptor.Rejected.class, () -> interceptor.preSend(
                frame(StompCommand.SUBSCRIBE, "/user/queue/messages", null, new HashMap<>(), null), channel));
    }

    @Test
    void roleIsTakenFromToken() {
        assertEquals(Role.USER, jwt.parse(token(5)).role());
    }
}
