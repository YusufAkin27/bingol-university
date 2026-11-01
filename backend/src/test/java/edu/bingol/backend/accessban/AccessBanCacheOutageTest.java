package edu.bingol.backend.accessban;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;

/** FIX-P02/A01#7: DB kesintisinde gecmis `nextExpiry` her istegi yeniden DB'ye gondermemeli. */
class AccessBanCacheOutageTest {

    /** Elle ilerletilen saat. */
    static final class MutableClock extends Clock {
        final AtomicLong millis = new AtomicLong(1_800_000_000_000L);

        @Override
        public java.time.ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return Instant.ofEpochMilli(millis.get());
        }
    }

    @Test
    void reloadFailureAfterAnExpiredBanDoesNotSendEveryRequestToTheDatabase() {
        MutableClock clock = new MutableClock();
        AccessBanRepository bans = mock(AccessBanRepository.class);
        AnonymizerRangeRepository anon = mock(AnonymizerRangeRepository.class);
        AccessBan timed = new AccessBan();
        timed.setId(5L);
        timed.setKind(AccessBan.IP);
        timed.setBanValue("198.51.100.7");
        timed.setExpiresAt(clock.instant().plusSeconds(10));
        when(bans.findLive(any())).thenReturn(List.of(timed))
                .thenThrow(new org.springframework.dao.DataAccessResourceFailureException("db down"));
        AccessBanCache cache = new AccessBanCache(bans, anon, clock, 20, false, "");
        ClientContext ctx = new ClientContext("198.51.100.7", null, null, null);

        assertNotNull(cache.match(ctx, null)); // ilk yukleme: engel canli

        clock.millis.addAndGet(30_000); // engel suresi ve TTL gecti; DB artik hata veriyor
        for (int i = 0; i < 50; i++) {
            cache.match(ctx, null); // eski goruntu ile devam
        }

        // 1 ilk yukleme + 1 basarisiz yenileme; sonraki 49 istek DB'ye gitmedi
        verify(bans, times(2)).findLive(any());
    }

    @Test
    void concurrentRequestsDuringASlowReloadServeTheOldSnapshotInsteadOfQueueing() throws Exception {
        MutableClock clock = new MutableClock();
        AccessBanRepository bans = mock(AccessBanRepository.class);
        AnonymizerRangeRepository anon = mock(AnonymizerRangeRepository.class);
        java.util.concurrent.CountDownLatch inReload = new java.util.concurrent.CountDownLatch(1);
        java.util.concurrent.CountDownLatch release = new java.util.concurrent.CountDownLatch(1);
        java.util.concurrent.atomic.AtomicInteger calls = new java.util.concurrent.atomic.AtomicInteger();
        when(bans.findLive(any())).thenAnswer(inv -> {
            if (calls.incrementAndGet() > 1) { // ilk cagri hizli, yenileme yavas
                inReload.countDown();
                release.await(5, java.util.concurrent.TimeUnit.SECONDS);
            }
            return List.of();
        });
        AccessBanCache cache = new AccessBanCache(bans, anon, clock, 20, false, "");
        ClientContext ctx = new ClientContext("198.51.100.7", null, null, null);
        cache.match(ctx, null);
        clock.millis.addAndGet(25_000); // TTL doldu

        Thread reloader = new Thread(() -> cache.match(ctx, null));
        reloader.start();
        assertEquals(true, inReload.await(5, java.util.concurrent.TimeUnit.SECONDS));

        long t0 = System.nanoTime();
        cache.match(ctx, null); // yenileme surerken: beklememeli
        long ms = (System.nanoTime() - t0) / 1_000_000;
        release.countDown();
        reloader.join();

        org.junit.jupiter.api.Assertions.assertTrue(ms < 1000, "ikinci istek yenilemeyi beklememeli, sure ms=" + ms);
        assertEquals(2, calls.get());
    }
}
