package edu.bingol.backend.forum.notify;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import edu.bingol.backend.forum.notify.spi.ForumEventPublisher.TargetType;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/** Olay yayincisi: argumanlari ForumNotifier'a iletir, hatayi yutar, islem varsa COMMIT'ten sonra calisir. */
class ForumEventPublisherImplTest {

    private final ForumNotifier notifier = mock(ForumNotifier.class);
    private final ForumEventPublisherImpl sync = new ForumEventPublisherImpl(notifier, false, 1, 10);

    @Test
    void forwardsAllFourEventsSynchronouslyWhenAsyncIsOff() {
        sync.topicLiked(5L, 2L);
        sync.commentCreated(7L, 2L);
        sync.commentLiked(7L, 3L);
        sync.moderationAction(TargetType.TOPIC, 5L, "REMOVE", "spam");
        sync.moderationAction(TargetType.COMMENT, 7L, "RESTORE", null);
        verify(notifier).topicLiked(5L, 2L);
        verify(notifier).commentCreated(7L, 2L);
        verify(notifier).commentLiked(7L, 3L);
        verify(notifier).moderated(false, 5L, "REMOVE", "spam");
        verify(notifier).moderated(true, 7L, "RESTORE", null);
    }

    @Test
    void nullArgumentsAreIgnoredAndErrorsNeverEscape() {
        sync.topicLiked(null, 2L);
        sync.commentCreated(7L, null);
        sync.moderationAction(null, 5L, "REMOVE", null);
        verify(notifier, never()).topicLiked(org.mockito.ArgumentMatchers.anyLong(), org.mockito.ArgumentMatchers.anyLong());
        doThrow(new IllegalStateException("db")).when(notifier).commentLiked(1L, 2L);
        sync.commentLiked(1L, 2L); // firlatmaz
    }

    @Test
    void asyncModeRunsOnAnotherThread() throws Exception {
        ForumEventPublisherImpl async = new ForumEventPublisherImpl(notifier, true, 1, 10);
        CountDownLatch done = new CountDownLatch(1);
        String[] thread = new String[1];
        org.mockito.Mockito.doAnswer(inv -> {
            thread[0] = Thread.currentThread().getName();
            done.countDown();
            return null;
        }).when(notifier).topicLiked(9L, 1L);
        async.topicLiked(9L, 1L);
        assertTrue(done.await(5, TimeUnit.SECONDS));
        assertTrue(thread[0].startsWith("forum-notify-"));
        async.shutdown();
    }

    @Test
    void insideATransactionTheEventWaitsForCommit() {
        TransactionSynchronizationManager.initSynchronization();
        try {
            sync.topicLiked(5L, 2L);
            verify(notifier, never()).topicLiked(5L, 2L); // henuz commit yok
            for (TransactionSynchronization s : TransactionSynchronizationManager.getSynchronizations()) {
                s.afterCommit();
            }
            verify(notifier).topicLiked(5L, 2L);
        } finally {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }
}
