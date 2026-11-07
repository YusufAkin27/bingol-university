package edu.bingol.backend.messaging.ws;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.connection.DefaultMessage;
import tools.jackson.databind.json.JsonMapper;

/**
 * FIX-P03 (A02#4): Redis dinleyici yurutucusu yoktu (olay basina yeni thread, ayni konusmanin olaylari ters sirada
 * teslim olabiliyordu). Konusma anahtarli seritler: ayni konusma FIFO, farkli konusmalar paralel.
 */
class OrderedBusListenerTest {

    private final JsonMapper mapper = JsonMapper.builder().build();
    private final ChatEventBus bus = mock(ChatEventBus.class);
    private final ExecutorService pool = Executors.newFixedThreadPool(4);

    @AfterEach
    void tearDown() {
        pool.shutdownNow();
    }

    private ChatEventBus.Envelope env(String dest, long convId, long seq) {
        return new ChatEventBus.Envelope(dest, List.of(1L), mapper.valueToTree(
                java.util.Map.of("conversationId", convId, "seq", seq)));
    }

    private static DefaultMessage raw(String tag) {
        return new DefaultMessage(ChatEventBus.CHANNEL.getBytes(StandardCharsets.UTF_8), tag.getBytes(StandardCharsets.UTF_8));
    }

    @Test
    void eventsOfTheSameConversationAreDeliveredInOrderEvenIfTheFirstIsSlow() throws Exception {
        List<String> order = new CopyOnWriteArrayList<>();
        CountDownLatch done = new CountDownLatch(3);
        when(bus.decode(anyString())).thenAnswer(inv -> switch ((String) inv.getArgument(0)) {
            case "e1" -> env("messages", 7, 1);
            case "e2" -> env("message-events", 7, 2);
            default -> env("messages", 8, 3);
        });
        doAnswer(inv -> {
            ChatEventBus.Envelope e = inv.getArgument(0);
            long seq = e.payload().get("seq").asLong();
            if (seq == 1) {
                Thread.sleep(200); // yavas ilk olay: ikincisi onu GECMEMELI
            }
            order.add("c" + e.payload().get("conversationId") + "#" + seq);
            done.countDown();
            return null;
        }).when(bus).deliverLocal(any());

        OrderedBusListener l = new OrderedBusListener(bus, pool, 1000);
        l.onMessage(raw("e1"), null);
        l.onMessage(raw("e2"), null);
        l.onMessage(raw("e3"), null);

        assertTrue(done.await(5, TimeUnit.SECONDS));
        assertTrue(order.indexOf("c7#1") < order.indexOf("c7#2"), "ayni konusma sirayla teslim edilmeli: " + order);
        // farkli konusma, yavas olani beklemez
        assertTrue(order.indexOf("c8#3") < order.indexOf("c7#1"), "farkli konusma paralel isler: " + order);
    }

    @Test
    void laneKeyUsesConversationIdElseFirstRecipient() {
        assertEquals("c7", OrderedBusListener.laneKey(env("messages", 7, 1)));
        assertEquals("u5", OrderedBusListener.laneKey(new ChatEventBus.Envelope("typing", List.of(5L, 6L),
                mapper.createObjectNode())));
    }

    @Test
    void invalidFrameIsDroppedWithoutThrowing() {
        when(bus.decode(anyString())).thenThrow(new IllegalArgumentException("bozuk"));
        new OrderedBusListener(bus, pool, 1000).onMessage(raw("x"), null);
    }

    @Test
    void lanesAreRemovedWhenDrained() throws Exception {
        CountDownLatch done = new CountDownLatch(1);
        when(bus.decode(anyString())).thenReturn(env("messages", 9, 1));
        doAnswer(inv -> {
            done.countDown();
            return null;
        }).when(bus).deliverLocal(any());
        OrderedBusListener l = new OrderedBusListener(bus, pool, 1000);

        l.onMessage(raw("a"), null);

        assertTrue(done.await(5, TimeUnit.SECONDS));
        for (int i = 0; i < 50 && l.laneCount() > 0; i++) {
            Thread.sleep(20);
        }
        assertEquals(0, l.laneCount());
    }
}
