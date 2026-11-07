package edu.bingol.backend.messaging.ws;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.auth.ProfileCompletionGate;
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

/** Profili tamamlanmamis kullanici STOMP uzerinden de mesaj gonderemez (HTTP kapisinin karsiligi). */
class StompProfileGateTest {

    private final StompAuthInterceptor interceptor = new StompAuthInterceptor(
            new JwtService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30)),
            mock(StringRedisTemplate.class));
    private final MessageChannel channel = mock(MessageChannel.class);
    private final ProfileCompletionGate gate = mock(ProfileCompletionGate.class);

    private static Message<byte[]> send(String userId) {
        StompHeaderAccessor acc = StompHeaderAccessor.create(StompCommand.SEND);
        acc.setDestination("/app/chat.send");
        acc.setSessionAttributes(new HashMap<>(Map.of("tokenExp", Instant.now().getEpochSecond() + 600)));
        acc.setUser(() -> userId);
        acc.setLeaveMutable(true);
        return MessageBuilder.createMessage(new byte[0], acc.getMessageHeaders());
    }

    @Test
    void incompleteProfileCannotSendOverStomp() {
        interceptor.setProfileGate(gate);
        when(gate.isIncomplete(5L)).thenReturn(true);
        when(gate.isIncomplete(6L)).thenReturn(false);

        var e = assertThrows(StompAuthInterceptor.Rejected.class, () -> interceptor.preSend(send("5"), channel));
        assertEquals("PROFILE_INCOMPLETE", e.getMessage());

        interceptor.preSend(send("6"), channel); // tamamlanmis: gecer
    }

    @Test
    void withoutTheGateBeanSendingIsUnaffected() {
        interceptor.preSend(send("5"), channel);
    }
}
