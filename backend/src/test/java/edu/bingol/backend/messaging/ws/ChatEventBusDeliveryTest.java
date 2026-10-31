package edu.bingol.backend.messaging.ws;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.crypto.BusCipher;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.messaging.simp.user.SimpUser;
import org.springframework.messaging.simp.user.SimpUserRegistry;
import tools.jackson.databind.json.JsonMapper;

/** T-036: WS teslimi alici sayisindan bagimsiz TEK Redis okumasi (MGET) yapar; askidakilere teslim edilmez. */
class ChatEventBusDeliveryTest {

    private final StringRedisTemplate redis = mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked")
    private final ValueOperations<String, String> ops = mock(ValueOperations.class);
    private final SimpMessagingTemplate template = mock(SimpMessagingTemplate.class);
    private final SimpUserRegistry registry = mock(SimpUserRegistry.class);
    private final JsonMapper mapper = JsonMapper.builder().build();
    private final ChatEventBus bus = new ChatEventBus(redis, template, registry, mapper, mock(BusCipher.class));

    private ChatEventBus.Envelope envelope(List<Long> ids) {
        return new ChatEventBus.Envelope("messages", ids, mapper.valueToTree("x"));
    }

    @Test
    void threeHundredRecipientsCostOneRedisReadAndNoPerRecipientExists() {
        when(redis.opsForValue()).thenReturn(ops);
        SimpUser connected = mock(SimpUser.class);
        List<Long> ids = new ArrayList<>();
        for (long i = 1; i <= 300; i++) {
            ids.add(i);
            when(registry.getUser(String.valueOf(i))).thenReturn(connected);
        }
        when(ops.multiGet(anyCollection())).thenAnswer(inv -> {
            List<String> out = new ArrayList<>();
            for (Object k : (java.util.Collection<?>) inv.getArgument(0)) {
                out.add(k.equals("suspended:7") ? "1" : null); // 7 askida
            }
            return out;
        });

        bus.deliverLocal(envelope(ids));

        verify(ops, times(1)).multiGet(anyCollection());
        verify(redis, never()).hasKey(anyString());
        verify(template, times(299)).convertAndSendToUser(anyString(), eq("/queue/messages"), any(Object.class));
        verify(template, never()).convertAndSendToUser(eq("7"), anyString(), any(Object.class));
    }

    @Test
    void onlyLocallyConnectedUsersAreLookedUp() {
        when(redis.opsForValue()).thenReturn(ops);
        SimpUser connected = mock(SimpUser.class);
        when(registry.getUser("1")).thenReturn(connected);
        when(registry.getUser("2")).thenReturn(null); // baska sunucuda / bagli degil
        when(ops.multiGet(anyCollection())).thenReturn(java.util.Collections.singletonList(null));

        bus.deliverLocal(envelope(List.of(1L, 2L)));

        @SuppressWarnings("unchecked")
        ArgumentCaptor<java.util.Collection<String>> keys = ArgumentCaptor.forClass(java.util.Collection.class);
        verify(ops).multiGet(keys.capture());
        org.junit.jupiter.api.Assertions.assertEquals(List.of("suspended:1"), List.copyOf(keys.getValue()));
        verify(template).convertAndSendToUser(eq("1"), eq("/queue/messages"), any(Object.class));
        verify(template, never()).convertAndSendToUser(eq("2"), anyString(), any(Object.class));
    }

    @Test
    void noLocalRecipientMeansNoRedisCall() {
        when(registry.getUser(anyString())).thenReturn(null);

        bus.deliverLocal(envelope(List.of(1L, 2L, 3L)));

        verify(redis, never()).opsForValue();
    }

    @Test
    void redisFailureDoesNotBlockDelivery() {
        when(redis.opsForValue()).thenReturn(ops);
        SimpUser connected = mock(SimpUser.class);
        when(registry.getUser("1")).thenReturn(connected);
        when(ops.multiGet(anyCollection())).thenThrow(new org.springframework.data.redis.RedisSystemException("x", null));

        bus.deliverLocal(envelope(List.of(1L)));

        verify(template).convertAndSendToUser(eq("1"), eq("/queue/messages"), any(Object.class));
    }
}
