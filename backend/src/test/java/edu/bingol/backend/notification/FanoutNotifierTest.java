package edu.bingol.backend.notification;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/** FINAL-ALL: uye/katilimci bildirimleri istek is parcaciginda ve commit oncesinde calismaz. */
class FanoutNotifierTest {

    @Test
    void jobRunsOnPoolThreadNotOnCaller() throws Exception {
        FanoutNotifier f = new FanoutNotifier();
        CountDownLatch done = new CountDownLatch(1);
        AtomicReference<String> thread = new AtomicReference<>();
        f.afterCommit("t", () -> {
            thread.set(Thread.currentThread().getName());
            done.countDown();
        });
        assertTrue(done.await(5, TimeUnit.SECONDS));
        assertNotEquals(Thread.currentThread().getName(), thread.get());
        assertEquals("notify-fanout", thread.get());
    }

    @Test
    void jobWaitsForCommitAndNeverRunsOnRollback() throws Exception {
        FanoutNotifier f = new FanoutNotifier();
        CountDownLatch done = new CountDownLatch(1);
        TransactionSynchronizationManager.initSynchronization();
        try {
            f.afterCommit("t", done::countDown);
            assertEquals(1, TransactionSynchronizationManager.getSynchronizations().size());
            // islem bitmeden is calismaz
            assertEquals(1, done.getCount());
            // geri alma: afterCommit cagrilmaz -> is hic calismaz
            for (TransactionSynchronization s : TransactionSynchronizationManager.getSynchronizations()) {
                s.afterCompletion(TransactionSynchronization.STATUS_ROLLED_BACK);
            }
        } finally {
            TransactionSynchronizationManager.clearSynchronization();
        }
        assertTrue(!done.await(300, TimeUnit.MILLISECONDS), "geri alinan islem bildirim gondermemeli");

        TransactionSynchronizationManager.initSynchronization();
        try {
            f.afterCommit("t", done::countDown);
            TransactionSynchronizationManager.getSynchronizations().forEach(TransactionSynchronization::afterCommit);
        } finally {
            TransactionSynchronizationManager.clearSynchronization();
        }
        assertTrue(done.await(5, TimeUnit.SECONDS), "commit sonrasi is calisir");
    }

    @Test
    void failingJobDoesNotKillThePoolOrThrow() throws Exception {
        FanoutNotifier f = new FanoutNotifier();
        f.afterCommit("boom", () -> {
            throw new IllegalStateException("x");
        });
        CountDownLatch done = new CountDownLatch(1);
        f.afterCommit("ok", done::countDown);
        assertTrue(done.await(5, TimeUnit.SECONDS));
    }

    @Test
    void fullQueueDropsJobAndCounts() throws Exception {
        FanoutNotifier f = new FanoutNotifier();
        CountDownLatch gate = new CountDownLatch(1);
        // iki is parcacigini da mesgul et, sonra kuyrugu doldur
        for (int i = 0; i < FanoutNotifier.THREADS; i++) {
            f.afterCommit("busy", () -> {
                try {
                    gate.await(10, TimeUnit.SECONDS);
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                }
            });
        }
        for (int i = 0; i < FanoutNotifier.QUEUE + 5; i++) {
            f.afterCommit("q", () -> { });
        }
        assertTrue(f.rejectedCount() >= 5, "kuyruk dolunca isler atilir ve sayilir");
        gate.countDown();
    }

    @Test
    void dispatchWithoutNotifierRunsInline() {
        boolean[] ran = {false};
        FanoutNotifier.dispatch(null, "t", () -> ran[0] = true);
        assertTrue(ran[0]);
    }
}
