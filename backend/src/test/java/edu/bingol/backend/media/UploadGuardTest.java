package edu.bingol.backend.media;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.common.ApiException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

/** Yukleme eszamanliligi (video semaforu + kullanici basina 1) ve gunluk kota. */
class UploadGuardTest {

    private static UploadGuard guard(int concurrent, long waitMs, int perDay, long bytesPerDay) {
        return new UploadGuard((org.springframework.data.redis.core.StringRedisTemplate) null, concurrent, waitMs,
                perDay, bytesPerDay);
    }

    @Test
    void fourthConcurrentVideoUploadIsRejectedWith429() {
        UploadGuard g = guard(3, 0, 1000, Long.MAX_VALUE);
        List<UploadGuard.Permit> held = new ArrayList<>();
        for (long u = 1; u <= 3; u++) {
            held.add(g.acquire(u, true));
        }
        assertEquals(0, g.availableHeavy());

        ApiException e = assertThrows(ApiException.class, () -> g.acquire(4L, true));
        assertEquals("UPLOAD_BUSY", e.code());
        assertEquals(429, e.status().value());

        held.get(0).close();
        assertEquals(1, g.availableHeavy());
        g.acquire(4L, true).close(); // izin geri verilince yeniden alinabilir
        held.subList(1, held.size()).forEach(UploadGuard.Permit::close);
        assertEquals(3, g.availableHeavy());
    }

    @Test
    void sameUserCannotRunTwoUploadsAtOnceAndFailedAcquireReturnsTheGlobalPermit() {
        UploadGuard g = guard(3, 0, 1000, Long.MAX_VALUE);
        UploadGuard.Permit first = g.acquire(7L, true);

        assertThrows(ApiException.class, () -> g.acquire(7L, true));
        assertThrows(ApiException.class, () -> g.acquire(7L, false));
        assertEquals(2, g.availableHeavy(), "reddedilen istek genel izni tutmamali");

        first.close();
        g.acquire(7L, true).close();
    }

    @Test
    void imageUploadsDoNotTakeTheHeavySemaphore() {
        UploadGuard g = guard(1, 0, 1000, Long.MAX_VALUE);
        UploadGuard.Permit video = g.acquire(1L, true);
        UploadGuard.Permit image = g.acquire(2L, false); // video izni dolu olsa da gorsel gecer
        image.close();
        video.close();
    }

    @Test
    void sequentialUploadsOfOneUserWaitInsteadOfFailing() throws Exception {
        UploadGuard g = guard(3, 2000, 1000, Long.MAX_VALUE);
        UploadGuard.Permit first = g.acquire(5L, false);
        ExecutorService pool = Executors.newSingleThreadExecutor();
        try {
            var second = pool.submit(() -> g.acquire(5L, false)); // bekler
            Thread.sleep(150);
            first.close();
            second.get(3, TimeUnit.SECONDS).close();
        } finally {
            pool.shutdownNow();
        }
    }

    @Test
    void parallelBurstNeverExceedsTheGlobalLimit() throws Exception {
        UploadGuard g = guard(3, 0, 1000, Long.MAX_VALUE);
        int threads = 12;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch start = new CountDownLatch(1);
        AtomicInteger inFlight = new AtomicInteger();
        AtomicInteger peak = new AtomicInteger();
        AtomicInteger rejected = new AtomicInteger();
        List<java.util.concurrent.Future<?>> fs = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            long user = 100 + i;
            fs.add(pool.submit(() -> {
                start.await();
                try (UploadGuard.Permit p = g.acquire(user, true)) {
                    int n = inFlight.incrementAndGet();
                    peak.accumulateAndGet(n, Math::max);
                    Thread.sleep(150);
                    inFlight.decrementAndGet();
                } catch (ApiException e) {
                    rejected.incrementAndGet();
                }
                return null;
            }));
        }
        start.countDown();
        for (var f : fs) {
            f.get(5, TimeUnit.SECONDS);
        }
        pool.shutdownNow();
        assertEquals(true, peak.get() <= 3, "en fazla 3 eszamanli: " + peak.get());
        assertEquals(true, rejected.get() >= 1);
        assertEquals(3, g.availableHeavy());
    }

    @Test
    void dailyCountQuotaIsEnforced() {
        UploadGuard g = guard(3, 0, 3, Long.MAX_VALUE);
        g.charge(9L, 10);
        g.charge(9L, 10);
        g.charge(9L, 10);
        ApiException e = assertThrows(ApiException.class, () -> g.charge(9L, 10));
        assertEquals("UPLOAD_QUOTA_EXCEEDED", e.code());
        g.charge(10L, 10); // baska kullanici etkilenmez
    }

    @Test
    void dailyByteQuotaIsEnforced() {
        UploadGuard g = guard(3, 0, 1000, 100L << 20);
        g.charge(9L, 40L << 20);
        g.charge(9L, 40L << 20);
        ApiException e = assertThrows(ApiException.class, () -> g.charge(9L, 40L << 20));
        assertEquals("UPLOAD_QUOTA_EXCEEDED", e.code());
    }
}
