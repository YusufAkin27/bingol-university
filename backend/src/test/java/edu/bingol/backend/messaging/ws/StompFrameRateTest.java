package edu.bingol.backend.messaging.ws;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.auth.jwt.JwtService;
import edu.bingol.backend.config.JwtProperties;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.MessageBuilder;

/** WebSocket SEND cerceve hiz siniri: asan cerceve atilir, asiri ise baglanti kapanir; baska kullanici etkilenmez. */
class StompFrameRateTest {

    private final MessageChannel channel = mock(MessageChannel.class);
    private final StompAuthInterceptor interceptor = new StompAuthInterceptor(
            new JwtService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30)),
            mock(StringRedisTemplate.class));

    private static Message<byte[]> send(String user) {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.SEND);
        acc.setDestination("/app/chat.send");
        acc.setSessionAttributes(new HashMap<>(Map.of("tokenExp", Instant.now().getEpochSecond() + 600)));
        acc.setUser(() -> user);
        acc.setLeaveMutable(true);
        return MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());
    }

    @Test
    void framesOverTheSecondLimitAreDroppedAndOtherUsersAreUnaffected() {
        interceptor.setMaxFramesPerSecond(5);
        interceptor.setNowMillis(() -> 1_000_000L);
        int passed = 0;
        int dropped = 0;
        for (int i = 0; i < 12; i++) {
            if (interceptor.preSend(send("5"), channel) == null) {
                dropped++;
            } else {
                passed++;
            }
        }
        assertEquals(5, passed);
        assertEquals(7, dropped);

        assertNotNull(interceptor.preSend(send("6"), channel), "baska kullanici etkilenmez");

        // Yeni saniye: sayac sifirlanir
        interceptor.setNowMillis(() -> 1_001_000L);
        assertNotNull(interceptor.preSend(send("5"), channel));
    }

    @Test
    void floodFarBeyondTheLimitClosesTheConnection() {
        interceptor.setMaxFramesPerSecond(2);
        interceptor.setNowMillis(() -> 5_000_000L);
        assertThrows(StompAuthInterceptor.Rejected.class, () -> {
            for (int i = 0; i < 40; i++) {
                interceptor.preSend(send("5"), channel);
            }
        });
    }

    @Test
    void frameOverLimitReturnsNullNotAnException() {
        interceptor.setMaxFramesPerSecond(1);
        interceptor.setNowMillis(() -> 9_000_000L);
        assertNotNull(interceptor.preSend(send("7"), channel));
        assertNull(interceptor.preSend(send("7"), channel));
    }
}
