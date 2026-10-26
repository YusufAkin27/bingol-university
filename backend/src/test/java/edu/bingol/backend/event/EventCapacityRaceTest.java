package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Kapasite yarisi: N es zamanli "GOING" istegi gercek veritabani transaction'lariyla calisir; kosullu UPDATE
 * sayesinde tam kapasite kadar rezervasyon basarili olmali, sayac asla asilmamali. (PostgreSQL ile ayni dogrulama
 * scripts/qa-event-race.sh icindedir.)
 */
@SpringBootTest
class EventCapacityRaceTest {

    @Autowired
    UserEventRepository events;

    @Autowired
    PlatformTransactionManager tm;

    private UserEvent newEvent(Integer capacity) {
        UserEvent e = new UserEvent();
        e.setTitle("Yaris");
        e.setStartsAt(Instant.now().plus(Duration.ofDays(1)));
        e.setEndsAt(Instant.now().plus(Duration.ofDays(1)).plus(Duration.ofHours(1)));
        e.setCapacity(capacity);
        e.setCreatedBy(1L);
        e.setStatus(UserEvent.Status.ACTIVE);
        return events.saveAndFlush(e);
    }

    private int race(Long eventId, int threads) throws Exception {
        TransactionTemplate tx = new TransactionTemplate(tm);
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger ok = new AtomicInteger();
        List<Future<?>> fs = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            Callable<Object> c = () -> {
                go.await();
                Integer n = tx.execute(s -> events.tryIncrementGoing(eventId));
                if (n != null && n == 1) {
                    ok.incrementAndGet();
                }
                return null;
            };
            fs.add(pool.submit(c));
        }
        go.countDown();
        for (Future<?> f : fs) {
            f.get();
        }
        pool.shutdown();
        return ok.get();
    }

    @Test
    void neverExceedsCapacityUnderConcurrentReservations() throws Exception {
        UserEvent e = newEvent(7);

        int ok = race(e.getId(), 40);

        assertEquals(7, ok);
        assertEquals(7, events.goingCount(e.getId()));
    }

    @Test
    void unlimitedEventAcceptsEveryone() throws Exception {
        UserEvent e = newEvent(null);

        int ok = race(e.getId(), 25);

        assertEquals(25, ok);
        assertEquals(25, events.goingCount(e.getId()));
    }

    @Test
    void decrementNeverGoesNegative() {
        UserEvent e = newEvent(3);
        TransactionTemplate tx = new TransactionTemplate(tm);

        tx.executeWithoutResult(s -> {
            events.decrementGoing(e.getId());
            events.decrementGoing(e.getId());
        });

        assertEquals(0, events.goingCount(e.getId()));
    }
}
