package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
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
 * FIX-P05 (A05#2): gercek veritabani transaction'lariyla es zamanli durum gecisi. Gecisi yalniz bir istek sahiplenir;
 * sayac bir kez degisir. (Eskiden iki istek de decrement/increment yapip going_count'u kaydiriyordu.) Ayrica gece
 * uzlastirmasi sapmis sayaci GOING satir sayisina esitler.
 */
@SpringBootTest
class EventRsvpTransitionRaceTest {

    @Autowired
    UserEventRepository events;

    @Autowired
    EventRsvpRepository rsvps;

    @Autowired
    PlatformTransactionManager tm;

    @Autowired
    EventGoingCountReconciler reconciler;

    private UserEvent newEvent(int going) {
        UserEvent e = new UserEvent();
        e.setTitle("Gecis yarisi");
        e.setStartsAt(Instant.now().plus(Duration.ofDays(1)));
        e.setEndsAt(Instant.now().plus(Duration.ofDays(1)).plus(Duration.ofHours(1)));
        e.setCapacity(50);
        e.setGoingCount(going);
        e.setCreatedBy(1L);
        e.setStatus(UserEvent.Status.ACTIVE);
        return events.saveAndFlush(e);
    }

    @Test
    void concurrentGoingToInterestedDecrementsExactlyOnce() throws Exception {
        UserEvent e = newEvent(2); // iki GOING: biri bu kullanici, biri baskasi
        EventRsvp mine = rsvps.saveAndFlush(new EventRsvp(e.getId(), 101L, EventRsvp.Status.GOING));
        rsvps.saveAndFlush(new EventRsvp(e.getId(), 102L, EventRsvp.Status.GOING));

        TransactionTemplate tx = new TransactionTemplate(tm);
        int threads = 12;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger winners = new AtomicInteger();
        List<Future<?>> fs = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            fs.add(pool.submit(() -> {
                go.await();
                tx.executeWithoutResult(s -> {
                    if (rsvps.transition(mine.getId(), EventRsvp.Status.GOING, EventRsvp.Status.INTERESTED) == 1) {
                        events.decrementGoing(e.getId());
                        winners.incrementAndGet();
                    }
                });
                return null;
            }));
        }
        go.countDown();
        for (Future<?> f : fs) {
            f.get();
        }
        pool.shutdown();

        assertEquals(1, winners.get());
        assertEquals(1, events.goingCount(e.getId())); // diger kullanicinin koltugu korunur
    }

    @Test
    void concurrentCancelDeletesAndDecrementsOnce() throws Exception {
        UserEvent e = newEvent(2);
        EventRsvp mine = rsvps.saveAndFlush(new EventRsvp(e.getId(), 111L, EventRsvp.Status.GOING));
        rsvps.saveAndFlush(new EventRsvp(e.getId(), 112L, EventRsvp.Status.GOING));

        TransactionTemplate tx = new TransactionTemplate(tm);
        ExecutorService pool = Executors.newFixedThreadPool(8);
        CountDownLatch go = new CountDownLatch(1);
        AtomicInteger winners = new AtomicInteger();
        List<Future<?>> fs = new ArrayList<>();
        for (int i = 0; i < 8; i++) {
            fs.add(pool.submit(() -> {
                go.await();
                tx.executeWithoutResult(s -> {
                    if (rsvps.deleteClaim(mine.getId()) == 1) {
                        events.decrementGoing(e.getId());
                        winners.incrementAndGet();
                    }
                });
                return null;
            }));
        }
        go.countDown();
        for (Future<?> f : fs) {
            f.get();
        }
        pool.shutdown();

        assertEquals(1, winners.get());
        assertEquals(1, events.goingCount(e.getId()));
    }

    @Test
    void nightlyReconcileFixesDriftedCounter() {
        UserEvent e = newEvent(5); // sayac 5, ama yalniz 2 GOING + 1 INTERESTED satiri var (hayalet koltuk)
        rsvps.saveAndFlush(new EventRsvp(e.getId(), 121L, EventRsvp.Status.GOING));
        rsvps.saveAndFlush(new EventRsvp(e.getId(), 122L, EventRsvp.Status.GOING));
        rsvps.saveAndFlush(new EventRsvp(e.getId(), 123L, EventRsvp.Status.INTERESTED));

        int fixed = reconciler.reconcile(Instant.now());

        assertEquals(true, fixed >= 1);
        assertEquals(2, events.goingCount(e.getId()));
        // ikinci calisma bu etkinlik icin bir sey degistirmez
        reconciler.reconcile(Instant.now());
        assertEquals(2, events.goingCount(e.getId()));
    }
}
