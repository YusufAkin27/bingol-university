package edu.bingol.backend.messaging.ws;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.messaging.Message;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.messaging.simp.SimpMessageType;
import org.springframework.messaging.support.ExecutorSubscribableChannel;
import org.springframework.messaging.support.MessageBuilder;

/**
 * T-037: ayni oturumdan hizli art arda gelen cerceveler GELIS SIRASIYLA islenir (gercek Spring kanali uzerinden:
 * aynisi kanal yurutucusu olarak WebSocketConfig'te kullanilir). Yorumlara degil davranisa guvenilir.
 */
class SessionOrderedExecutorTest {

    private SessionOrderedExecutor executor;
    private ExecutorSubscribableChannel channel;

    @BeforeEach
    void setUp() {
        executor = new SessionOrderedExecutor(8);
        executor.initialize();
        channel = new ExecutorSubscribableChannel(executor);
        channel.addInterceptor(new SessionOrderedExecutor.KeyInterceptor());
    }

    @AfterEach
    void tearDown() {
        executor.shutdown();
    }

    private static Message<String> frame(String session, int seq) {
        SimpMessageHeaderAccessor h = SimpMessageHeaderAccessor.create(SimpMessageType.MESSAGE);
        h.setSessionId(session);
        h.setLeaveMutable(true);
        return MessageBuilder.createMessage(session + ":" + seq, h.getMessageHeaders());
    }

    @Test
    void framesOfOneSessionRunInArrivalOrderEvenWhenEarlierOnesAreSlower() throws Exception {
        List<Integer> order = Collections.synchronizedList(new ArrayList<>());
        CountDownLatch done = new CountDownLatch(40);
        channel.subscribe(m -> {
            int seq = Integer.parseInt(((String) m.getPayload()).split(":")[1]);
            // erken cerceveler daha yavas: sirasiz havuzda tersine donerdi (A10-03: r0 r3 r2 r1 ...)
            sleep(seq % 3 == 0 ? 8 : 1);
            order.add(seq);
            done.countDown();
        });

        for (int i = 0; i < 40; i++) {
            channel.send(frame("s1", i));
        }

        assertTrue(done.await(10, TimeUnit.SECONDS));
        List<Integer> expected = new ArrayList<>();
        for (int i = 0; i < 40; i++) {
            expected.add(i);
        }
        assertEquals(expected, order);
    }

    @Test
    void differentSessionsStillRunInParallel() throws Exception {
        CountDownLatch bothInside = new CountDownLatch(2);
        CountDownLatch release = new CountDownLatch(1);
        channel.subscribe(m -> {
            bothInside.countDown();
            try {
                release.await(5, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        channel.send(frame("a", 0));
        channel.send(frame("b", 0));

        assertTrue(bothInside.await(5, TimeUnit.SECONDS), "iki oturum ayni anda islenmeli (tek is parcacigi degil)");
        release.countDown();
    }

    @Test
    void manySessionsSendingConcurrentlyEachKeepTheirOwnOrder() throws Exception {
        int sessions = 12;
        int perSession = 60;
        Map<String, List<Integer>> seen = new ConcurrentHashMap<>();
        CountDownLatch done = new CountDownLatch(sessions * perSession);
        channel.subscribe(m -> {
            String[] p = ((String) m.getPayload()).split(":");
            sleep(ThreadLocalRandom.current().nextInt(0, 3));
            seen.computeIfAbsent(p[0], k -> Collections.synchronizedList(new ArrayList<>())).add(Integer.parseInt(p[1]));
            done.countDown();
        });

        List<Thread> senders = new ArrayList<>();
        for (int s = 0; s < sessions; s++) {
            String id = "sess" + s;
            Thread t = new Thread(() -> {
                for (int i = 0; i < perSession; i++) {
                    channel.send(frame(id, i)); // her oturum kendi parcaciginda ardisik gonderir (WS oturumu gibi)
                }
            });
            senders.add(t);
            t.start();
        }
        for (Thread t : senders) {
            t.join();
        }

        assertTrue(done.await(20, TimeUnit.SECONDS));
        for (int s = 0; s < sessions; s++) {
            List<Integer> got = seen.get("sess" + s);
            assertEquals(perSession, got.size());
            for (int i = 0; i < perSession; i++) {
                assertEquals(i, got.get(i), "oturum sess" + s + " sirasi bozuldu: " + got);
            }
        }
        // bitince seritler temizlenir (bellek sizintisi yok)
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (executor.laneCount() > 0 && System.nanoTime() < deadline) {
            sleep(10);
        }
        assertEquals(0, executor.laneCount());
    }

    @Test
    void hotSessionYieldsAfterMaxRunSoOthersAreNotStarved() throws Exception {
        SessionOrderedExecutor single = new SessionOrderedExecutor(1);
        single.initialize();
        try {
            ExecutorSubscribableChannel ch = new ExecutorSubscribableChannel(single);
            ch.addInterceptor(new SessionOrderedExecutor.KeyInterceptor());
            AtomicInteger hotDone = new AtomicInteger();
            AtomicInteger hotAtColdTime = new AtomicInteger(-1);
            CountDownLatch gateEntered = new CountDownLatch(1);
            CountDownLatch release = new CountDownLatch(1);
            CountDownLatch all = new CountDownLatch(SessionOrderedExecutor.MAX_RUN * 3 + 2);
            ch.subscribe(m -> {
                String p = (String) m.getPayload();
                if (p.startsWith("gate")) {
                    gateEntered.countDown();
                    try {
                        release.await(10, TimeUnit.SECONDS);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                } else if (p.startsWith("hot")) {
                    hotDone.incrementAndGet();
                } else {
                    hotAtColdTime.set(hotDone.get());
                }
                all.countDown();
            });
            // tek is parcacigini kapi oturumuyla tut; sicak (96) ve soguk (1) cerceveleri kuyruga dizilsin (deterministik)
            ch.send(frame("gate", 0));
            assertTrue(gateEntered.await(5, TimeUnit.SECONDS));
            for (int i = 0; i < SessionOrderedExecutor.MAX_RUN * 3; i++) {
                ch.send(frame("hot", i));
            }
            ch.send(frame("cold", 0));
            release.countDown();

            assertTrue(all.await(10, TimeUnit.SECONDS));
            assertEquals(SessionOrderedExecutor.MAX_RUN, hotAtColdTime.get(),
                    "soguk oturum, sicak oturumun ilk MAX_RUN gorevinden sonra (tamami bitmeden) calismali");
        } finally {
            single.shutdown();
        }
    }

    @Test
    void framesWithoutSessionBypassTheLanes() throws Exception {
        CountDownLatch done = new CountDownLatch(1);
        channel.subscribe(m -> done.countDown());

        channel.send(MessageBuilder.withPayload("x").build()); // oturum basligi yok

        assertTrue(done.await(5, TimeUnit.SECONDS));
        assertFalse(executor.laneCount() > 0);
    }

    private static void sleep(long ms) {
        try {
            Thread.sleep(ms);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
