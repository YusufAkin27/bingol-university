package edu.bingol.backend.post.notify;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;

/**
 * A06#10: takip/istek bildirimi afterCommit'te istek ipliginde yeni islem (REQUIRES_NEW) acip havuzdan 2. baglanti
 * tutuyordu. Dispatcher bildirimi sinirli bir yurutucuya birakir; varsayilan (async=false) bugunku davranis: ayni iplik.
 */
class NotifyDispatcherTest {

    @Test
    void defaultRunsInlineOnCallingThread() {
        NotifyDispatcher d = new NotifyDispatcher(false, 2, 10);
        AtomicReference<Thread> ran = new AtomicReference<>();
        d.run(() -> ran.set(Thread.currentThread()));
        assertEquals(Thread.currentThread(), ran.get());
    }

    @Test
    void asyncRunsOnAWorkerThread() throws Exception {
        NotifyDispatcher d = new NotifyDispatcher(true, 2, 10);
        try {
            AtomicReference<Thread> ran = new AtomicReference<>();
            CountDownLatch done = new CountDownLatch(1);
            d.run(() -> {
                ran.set(Thread.currentThread());
                done.countDown();
            });
            assertTrue(done.await(5, TimeUnit.SECONDS));
            assertNotEquals(Thread.currentThread(), ran.get());
        } finally {
            d.shutdown();
        }
    }

    @Test
    void fullQueueDropsQuietlyAndNeverThrows() throws Exception {
        NotifyDispatcher d = new NotifyDispatcher(true, 1, 1);
        try {
            CountDownLatch block = new CountDownLatch(1);
            AtomicInteger ran = new AtomicInteger();
            d.run(() -> { // calisan: iplik bloklu
                try {
                    block.await(5, TimeUnit.SECONDS);
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                }
                ran.incrementAndGet();
            });
            for (int i = 0; i < 20; i++) { // kuyruk (1) dolar; fazlasi sessizce atilir
                d.run(ran::incrementAndGet);
            }
            block.countDown();
            for (int i = 0; i < 50 && ran.get() < 2; i++) {
                Thread.sleep(50);
            }
            assertTrue(ran.get() >= 2 && ran.get() < 21, "calisan: " + ran.get());
            assertTrue(d.dropped() > 0);
        } finally {
            d.shutdown();
        }
    }

    @Test
    void failingTaskDoesNotKillTheWorker() throws Exception {
        NotifyDispatcher d = new NotifyDispatcher(true, 1, 10);
        try {
            d.run(() -> {
                throw new IllegalStateException("boom");
            });
            CountDownLatch ok = new CountDownLatch(1);
            d.run(ok::countDown);
            assertTrue(ok.await(5, TimeUnit.SECONDS));
        } finally {
            d.shutdown();
        }
    }
}
