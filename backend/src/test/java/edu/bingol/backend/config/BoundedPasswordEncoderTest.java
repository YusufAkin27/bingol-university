package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.RateLimitedException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

class BoundedPasswordEncoderTest {

    /** Eşzamanlı çağrıları sayan yavaş taklit özetleyici. */
    private static final class SlowEncoder implements PasswordEncoder {
        final AtomicInteger running = new AtomicInteger();
        final AtomicInteger max = new AtomicInteger();
        final long holdMs;

        SlowEncoder(long holdMs) {
            this.holdMs = holdMs;
        }

        @Override
        public String encode(CharSequence raw) {
            return "h:" + raw;
        }

        @Override
        public boolean matches(CharSequence raw, String enc) {
            int now = running.incrementAndGet();
            max.accumulateAndGet(now, Math::max);
            try {
                Thread.sleep(holdMs);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            } finally {
                running.decrementAndGet();
            }
            return enc.equals("h:" + raw);
        }
    }

    @Test
    void delegatesToBcrypt() {
        BoundedPasswordEncoder enc = new BoundedPasswordEncoder(new BCryptPasswordEncoder(4), 1, 4, 1000);
        String h = enc.encode("Sifre1234");
        assertTrue(enc.matches("Sifre1234", h));
        assertFalse(enc.matches("yanlis", h));
        assertEquals(1, enc.availablePermits(), "izin geri verilmeli");
    }

    @Test
    void limitsConcurrentHashing() throws Exception {
        SlowEncoder slow = new SlowEncoder(60);
        BoundedPasswordEncoder enc = new BoundedPasswordEncoder(slow, 2, 20, 5000);
        List<Thread> ts = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            Thread t = new Thread(() -> enc.matches("a", "h:a"));
            ts.add(t);
            t.start();
        }
        for (Thread t : ts) {
            t.join();
        }
        assertTrue(slow.max.get() <= 2, "en cok 2 eşzamanlı özetleme, görülen: " + slow.max.get());
        assertEquals(2, enc.availablePermits());
        assertEquals(0, enc.waitingCount());
    }

    @Test
    void timesOutWith429WhenQueueWaitIsTooLong() throws Exception {
        SlowEncoder slow = new SlowEncoder(400);
        BoundedPasswordEncoder enc = new BoundedPasswordEncoder(slow, 1, 4, 50);
        CountDownLatch started = new CountDownLatch(1);
        Thread holder = new Thread(() -> {
            started.countDown();
            enc.matches("a", "h:a");
        });
        holder.start();
        started.await();
        Thread.sleep(80); // izin alındı
        RateLimitedException e = assertThrows(RateLimitedException.class, () -> enc.matches("b", "h:b"));
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, e.status());
        assertEquals(BoundedPasswordEncoder.RETRY_AFTER_SECONDS, e.retryAfterSeconds());
        holder.join();
        assertEquals(1, enc.availablePermits());
        assertEquals(0, enc.waitingCount());
    }

    @Test
    void rejectsImmediatelyWhenQueueIsFull() throws Exception {
        SlowEncoder slow = new SlowEncoder(600);
        BoundedPasswordEncoder enc = new BoundedPasswordEncoder(slow, 1, 1, 10_000);
        Thread holder = new Thread(() -> enc.matches("a", "h:a"));
        holder.start();
        Thread.sleep(100); // izin dolu
        Thread queued = new Thread(() -> enc.matches("b", "h:b")); // sırada tek kişi
        queued.start();
        Thread.sleep(100);
        assertEquals(1, enc.waitingCount());
        long t0 = System.nanoTime();
        assertThrows(RateLimitedException.class, () -> enc.matches("c", "h:c")); // sıra dolu: anında
        assertTrue((System.nanoTime() - t0) / 1_000_000 < 200, "anında reddedilmeli");
        holder.join();
        queued.join();
        assertEquals(1, enc.availablePermits());
        assertEquals(0, enc.waitingCount());
    }
}
