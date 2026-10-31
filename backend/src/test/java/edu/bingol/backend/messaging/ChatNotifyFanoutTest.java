package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;
import org.junit.jupiter.api.Test;

/** T-035: sohbet basina birlestirme ve dolu kuyrukta sessiz atlama yerine bekletme/yeniden deneme. */
class ChatNotifyFanoutTest {

    /** Elle bosaltilan, kapasiteli yurutucu: kapasite asilinca RejectedExecutionException. */
    static final class ManualExecutor implements Executor {
        final ArrayDeque<Runnable> queue = new ArrayDeque<>();
        final int capacity;

        ManualExecutor(int capacity) {
            this.capacity = capacity;
        }

        @Override
        public void execute(Runnable r) {
            if (queue.size() >= capacity) {
                throw new RejectedExecutionException("dolu");
            }
            queue.add(r);
        }

        void runOne() {
            queue.poll().run();
        }

        void runAll() {
            while (!queue.isEmpty()) {
                runOne();
            }
        }
    }

    private static ChatNotifyFanout.Job job(long conv, String preview, int count) {
        return new ChatNotifyFanout.Job(1L, conv, null, preview, false, Map.of(), List.of(2L, 3L), count);
    }

    @Test
    void messagesForTheSameConversationBehindABacklogMergeIntoOneJobWithSummedCount() {
        List<ChatNotifyFanout.Job> ran = new ArrayList<>();
        ChatNotifyFanout fanout = new ChatNotifyFanout(ran::add);
        ManualExecutor ex = new ManualExecutor(10);

        for (int i = 1; i <= 8; i++) {
            fanout.submit(ex, job(60001, "m" + i, 1)); // 8 mesaj, hicbiri henuz calismadi
        }

        assertEquals(1, ex.queue.size(), "tek gorev kuyrukta");
        assertEquals(7, fanout.coalescedCount());
        ex.runAll();
        assertEquals(1, ran.size());
        assertEquals(8, ran.get(0).count(), "sayac toplanir");
        assertEquals("m8", ran.get(0).preview(), "son mesaj kazanir");
        assertEquals(0, fanout.pendingCount());
    }

    @Test
    void idlePoolKeepsEveryMessageAsItsOwnJob() {
        List<ChatNotifyFanout.Job> ran = new ArrayList<>();
        ChatNotifyFanout fanout = new ChatNotifyFanout(ran::add);

        for (int i = 1; i <= 5; i++) {
            fanout.submit(Runnable::run, job(7, "m" + i, 1)); // her gorev hemen calisir
        }

        assertEquals(5, ran.size());
        assertTrue(ran.stream().allMatch(j -> j.count() == 1));
        assertEquals(0, fanout.coalescedCount());
    }

    @Test
    void differentConversationsAreIndependent() {
        List<ChatNotifyFanout.Job> ran = new ArrayList<>();
        ChatNotifyFanout fanout = new ChatNotifyFanout(ran::add);
        ManualExecutor ex = new ManualExecutor(10);

        fanout.submit(ex, job(1, "a", 1));
        fanout.submit(ex, job(2, "b", 1));
        fanout.submit(ex, job(1, "c", 1));

        assertEquals(2, ex.queue.size());
        ex.runAll();
        assertEquals(2, ran.size());
    }

    @Test
    void fullQueueDoesNotDropTheJobItIsCountedHeldAndRetriedWhenARunFinishes() {
        List<ChatNotifyFanout.Job> ran = new ArrayList<>();
        ChatNotifyFanout fanout = new ChatNotifyFanout(ran::add);
        ManualExecutor ex = new ManualExecutor(2);

        fanout.submit(ex, job(1, "a", 1));
        fanout.submit(ex, job(2, "b", 1));
        fanout.submit(ex, job(3, "c", 1)); // kuyruk dolu -> reddedildi

        assertEquals(2, ex.queue.size());
        assertEquals(1, fanout.rejectedCount(), "ret sayilir (metrik)");
        assertEquals(3, fanout.pendingCount(), "is kaybolmadi, bekliyor");

        ex.runOne(); // 1. gorev biter -> yer acilir -> reddedilen yeniden kuyruga alinir
        ex.runAll();

        assertEquals(3, ran.size(), "uc sohbetin bildirimi de dagitildi");
        assertEquals(0, fanout.pendingCount());
        assertEquals(0, fanout.droppedCount());
    }

    @Test
    void newMessageForAHeldConversationMergesAndRetriesSubmission() {
        List<ChatNotifyFanout.Job> ran = new ArrayList<>();
        ChatNotifyFanout fanout = new ChatNotifyFanout(ran::add);
        ManualExecutor ex = new ManualExecutor(1);

        fanout.submit(ex, job(1, "a", 1));
        fanout.submit(ex, job(2, "b", 1)); // reddedildi, bekliyor
        fanout.submit(ex, job(2, "b2", 1)); // bekleyenle birlesir, yeniden denenir (hala dolu)

        assertEquals(2, fanout.rejectedCount());
        ex.runAll();

        assertEquals(2, ran.size());
        ChatNotifyFanout.Job second = ran.stream().filter(j -> j.conversationId() == 2).findFirst().orElseThrow();
        assertEquals(2, second.count());
        assertEquals("b2", second.preview());
    }

    @Test
    void workerFailureDoesNotBreakTheQueue() {
        List<Long> ok = new ArrayList<>();
        ChatNotifyFanout fanout = new ChatNotifyFanout(j -> {
            if (j.conversationId() == 1) {
                throw new IllegalStateException("bozuk");
            }
            ok.add(j.conversationId());
        });

        fanout.submit(Runnable::run, job(1, "a", 1));
        fanout.submit(Runnable::run, job(2, "b", 1));

        assertEquals(List.of(2L), ok);
        assertEquals(0, fanout.pendingCount());
    }
}
