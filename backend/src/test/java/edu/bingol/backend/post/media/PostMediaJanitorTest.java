package edu.bingol.backend.post.media;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Duration;
import org.junit.jupiter.api.Test;

/** A06#13: medya temizligi coklu ornekte cift taramasin diye SchedulerLock ile sarili. */
class PostMediaJanitorTest {

    private final PostMediaService service = mock(PostMediaService.class);
    private final SchedulerLock lock = mock(SchedulerLock.class);
    private final PostMediaJanitor janitor = new PostMediaJanitor(service, lock, 24);

    @Test
    void unattachedSweepRunsOnlyUnderTheLock() {
        when(lock.tryRun(eq("post-media-unattached"), any(Duration.class), any(Runnable.class))).thenReturn(false);
        janitor.unattached();
        verify(service, never()).sweepUnattached(any());
    }

    @Test
    void deletedSweepRunsOnlyUnderTheLock() {
        when(lock.tryRun(eq("post-media-deleted"), any(Duration.class), any(Runnable.class))).thenReturn(false);
        janitor.deleted();
        verify(service, never()).sweepDeleted();
    }

    @Test
    void sweepRunsWhenLockIsHeld() {
        when(lock.tryRun(anyString(), any(Duration.class), any(Runnable.class))).thenAnswer(inv -> {
            inv.<Runnable>getArgument(2).run();
            return true;
        });
        janitor.unattached();
        janitor.deleted();
        verify(service).sweepUnattached(Duration.ofHours(24));
        verify(service).sweepDeleted();
    }
}
