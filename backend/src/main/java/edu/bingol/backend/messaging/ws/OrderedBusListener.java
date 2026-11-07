package edu.bingol.backend.messaging.ws;

import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executor;
import java.util.concurrent.atomic.AtomicInteger;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;

/**
 * Redis pub/sub dinleyicisi ile {@link ChatEventBus#deliverLocal} arasina konur (FIX-P03, A02#4). Kapsayici
 * (RedisMessageListenerContainer) yurutucu verilmediginde her mesaj icin yeni bir is parcacigi acar: sinirsiz thread
 * ve ayni konusmanin iki olayinin (ornegin mesaj ve duzenleme) ters sirada teslimi. Burada olaylar KONUSMA anahtarli
 * seritlere (FIFO) konur: ayni konusma sirayla, farkli konusmalar sinirli havuzda paralel isler. Konusmasiz olaylar
 * ilk aliciya gore seritlenir. Bekleyen is `maxPending`i asarsa olay atilir ve uyarilir (pub/sub zaten kalici degil;
 * istemci yeniden baglaninca `after=` ile eksikleri veritabanindan ceker).
 */
public final class OrderedBusListener implements MessageListener {

    private static final Logger log = LoggerFactory.getLogger(OrderedBusListener.class);
    /** Bir serit bir parcaciga bu kadar gorev ust uste verirse siraya geri doner (tek konusma havuzu tutmasin). */
    static final int MAX_RUN = 32;

    private final ChatEventBus bus;
    private final Executor pool;
    private final int maxPending;
    private final Map<String, ArrayDeque<Runnable>> lanes = new ConcurrentHashMap<>();
    private final AtomicInteger pending = new AtomicInteger();

    public OrderedBusListener(ChatEventBus bus, Executor pool, int maxPending) {
        this.bus = bus;
        this.pool = pool;
        this.maxPending = Math.max(100, maxPending);
    }

    @Override
    public void onMessage(Message message, byte[] pattern) {
        ChatEventBus.Envelope env;
        try {
            env = bus.decode(new String(message.getBody(), StandardCharsets.UTF_8));
        } catch (RuntimeException e) {
            log.warn("Gecersiz sohbet olayi atlandi: {}", e.toString());
            return;
        }
        if (pending.incrementAndGet() > maxPending) {
            pending.decrementAndGet();
            log.warn("Sohbet olay kuyrugu dolu ({}), olay atildi (dest {})", maxPending, env.dest());
            return;
        }
        submit(laneKey(env), () -> {
            try {
                bus.deliverLocal(env);
            } finally {
                pending.decrementAndGet();
            }
        });
    }

    static String laneKey(ChatEventBus.Envelope env) {
        if (env.payload() != null) {
            var cid = env.payload().get("conversationId");
            if (cid != null && !cid.isNull()) {
                return "c" + cid;
            }
        }
        return env.userIds().isEmpty() ? "-" : "u" + env.userIds().get(0);
    }

    private void submit(String key, Runnable task) {
        boolean[] start = {false};
        lanes.compute(key, (k, lane) -> {
            if (lane == null) {
                lane = new ArrayDeque<>();
                start[0] = true;
            }
            lane.add(task);
            return lane;
        });
        if (start[0]) {
            schedule(key);
        }
    }

    private void schedule(String key) {
        try {
            pool.execute(() -> drain(key));
        } catch (RuntimeException e) {
            // havuz kapali / reddetti: serit takili kalmasin, bekleyen gorevler sayactan duser
            ArrayDeque<Runnable> dropped = lanes.remove(key);
            if (dropped != null) {
                pending.addAndGet(-dropped.size());
            }
            log.warn("Sohbet olay seridi planlanamadi: {}", e.toString());
        }
    }

    private void drain(String key) {
        for (int i = 0; i < MAX_RUN; i++) {
            Runnable[] next = new Runnable[1];
            // poll + "bos serit = kaldir" tek atomik adimda: yeni gelen gorev ya bu seritte bekler ya yeni serit acar
            lanes.computeIfPresent(key, (k, lane) -> {
                next[0] = lane.poll();
                return next[0] == null ? null : lane;
            });
            if (next[0] == null) {
                return;
            }
            try {
                next[0].run();
            } catch (Throwable t) {
                log.warn("Sohbet olayi teslimi basarisiz (serit {}): {}", key, t.toString());
            }
        }
        schedule(key); // adil: diger seritlere firsat ver
    }

    /** Bekleyen serit sayisi (test/izleme). */
    int laneCount() {
        return lanes.size();
    }
}
