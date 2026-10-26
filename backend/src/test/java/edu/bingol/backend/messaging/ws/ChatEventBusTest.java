package edu.bingol.backend.messaging.ws;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.crypto.BusCipher;
import edu.bingol.backend.crypto.ConfiguredKeyProvider;
import edu.bingol.backend.crypto.CryptoProperties;
import edu.bingol.backend.crypto.CryptoService;
import java.nio.charset.StandardCharsets;
import org.springframework.core.env.StandardEnvironment;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.connection.DefaultMessage;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.messaging.simp.user.SimpUser;
import org.springframework.messaging.simp.user.SimpUserRegistry;
import tools.jackson.databind.json.JsonMapper;

class ChatEventBusTest {

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    private final SimpMessagingTemplate template = mock(SimpMessagingTemplate.class);
    private final SimpUserRegistry registry = mock(SimpUserRegistry.class);
    private final BusCipher busCipher = new BusCipher(new ConfiguredKeyProvider(
            new CryptoProperties("k1:AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=", "", "", false, true, 300, 1024, 30, 200),
            new StandardEnvironment()), new CryptoService());
    private final ChatEventBus bus = new ChatEventBus(redis, template, registry, JsonMapper.builder().build(), busCipher);

    private DefaultMessage event(String json) {
        return new DefaultMessage(ChatEventBus.CHANNEL.getBytes(StandardCharsets.UTF_8), busCipher.seal(json).getBytes(StandardCharsets.UTF_8));
    }

    @Test
    void deliversOnlyToUsersConnectedToThisNode() {
        when(registry.getUser("1")).thenReturn(mock(SimpUser.class));
        when(registry.getUser("2")).thenReturn(null);

        bus.onMessage(event("{\"dest\":\"messages\",\"userIds\":[1,2],\"payload\":{\"id\":5}}"), null);

        verify(template).convertAndSendToUser(eq("1"), eq("/queue/messages"), any(Object.class));
        verify(template, never()).convertAndSendToUser(eq("2"), any(), any(Object.class));
    }

    @Test
    void suspendedUserWithOpenSessionIsNotDelivered() {
        // Regresyon: WS ortasinda askiya alinan kullanici acik oturumuna mesaj almaya devam ediyordu.
        when(registry.getUser("1")).thenReturn(mock(SimpUser.class));
        when(registry.getUser("2")).thenReturn(mock(SimpUser.class));
        when(redis.hasKey("suspended:1")).thenReturn(true);
        when(redis.hasKey("suspended:2")).thenReturn(false);

        bus.onMessage(event("{\"dest\":\"messages\",\"userIds\":[1,2],\"payload\":{\"id\":5}}"), null);

        verify(template, never()).convertAndSendToUser(eq("1"), any(), any(Object.class));
        verify(template).convertAndSendToUser(eq("2"), eq("/queue/messages"), any(Object.class));
    }

    @Test
    void redisFailureOnSuspendCheckStillDelivers() {
        when(registry.getUser("1")).thenReturn(mock(SimpUser.class));
        when(redis.hasKey("suspended:1")).thenThrow(new IllegalStateException("redis yok"));

        bus.onMessage(event("{\"dest\":\"typing\",\"userIds\":[1],\"payload\":{\"x\":1}}"), null);

        verify(template).convertAndSendToUser(eq("1"), eq("/queue/typing"), any(Object.class));
    }

    @Test
    void publishWritesOnlyEncryptedFrameToRedis() {
        bus.publish("messages", java.util.List.of(1L), java.util.Map.of("text", "cok-gizli-metin"));

        org.mockito.ArgumentCaptor<String> sent = org.mockito.ArgumentCaptor.forClass(String.class);
        verify(redis).convertAndSend(eq(ChatEventBus.CHANNEL), sent.capture());
        org.junit.jupiter.api.Assertions.assertFalse(sent.getValue().contains("cok-gizli-metin"));
        org.junit.jupiter.api.Assertions.assertTrue(sent.getValue().startsWith("v1."));
        // Gidis-donus: kanaldan gelen cerceve cozulup yerel kullaniciya iletilir
        when(registry.getUser("1")).thenReturn(mock(SimpUser.class));
        bus.onMessage(new DefaultMessage(ChatEventBus.CHANNEL.getBytes(StandardCharsets.UTF_8),
                sent.getValue().getBytes(StandardCharsets.UTF_8)), null);
        verify(template).convertAndSendToUser(eq("1"), eq("/queue/messages"), any(Object.class));
    }

    @Test
    void plaintextOrTamperedFrameIsDropped() {
        when(registry.getUser("1")).thenReturn(mock(SimpUser.class));
        String json = "{\"dest\":\"messages\",\"userIds\":[1],\"payload\":{\"id\":5}}";
        bus.onMessage(new DefaultMessage(ChatEventBus.CHANNEL.getBytes(StandardCharsets.UTF_8),
                json.getBytes(StandardCharsets.UTF_8)), null); // duz JSON artik kabul edilmez
        String frame = busCipher.seal(json);
        String tampered = frame.substring(0, frame.length() - 3) + (frame.endsWith("AAA") ? "BBB" : "AAA");
        bus.onMessage(new DefaultMessage(ChatEventBus.CHANNEL.getBytes(StandardCharsets.UTF_8),
                tampered.getBytes(StandardCharsets.UTF_8)), null);
        verify(template, never()).convertAndSendToUser(any(), any(), any(Object.class));
    }

    @Test
    void malformedEventIsSkippedWithoutThrowing() {
        bus.onMessage(event("{bozuk"), null);
        verify(template, never()).convertAndSendToUser(any(), any(), any(Object.class));
    }
}
