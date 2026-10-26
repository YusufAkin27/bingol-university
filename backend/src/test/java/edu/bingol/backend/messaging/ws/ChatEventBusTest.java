package edu.bingol.backend.messaging.ws;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.nio.charset.StandardCharsets;
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
    private final ChatEventBus bus = new ChatEventBus(redis, template, registry, JsonMapper.builder().build());

    private static DefaultMessage event(String json) {
        return new DefaultMessage(ChatEventBus.CHANNEL.getBytes(StandardCharsets.UTF_8), json.getBytes(StandardCharsets.UTF_8));
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
    void malformedEventIsSkippedWithoutThrowing() {
        bus.onMessage(event("{bozuk"), null);
        verify(template, never()).convertAndSendToUser(any(), any(), any(Object.class));
    }
}
