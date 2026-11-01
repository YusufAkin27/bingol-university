package edu.bingol.backend.post;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Pageable;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * A06#8: Kesfet puani yeniden hesabi (a) son 24 sa begenilerini parti basina degil TEK GROUP BY ile okur,
 * (b) eski gonderileri sifirlayan tam-tablo UPDATE'i her 5 dk turunda degil aralikla (zero-old-interval-ms) calistirir.
 */
class PostRankServiceTest {

    private final PostRepository posts = mock(PostRepository.class);
    private final PostRankRepository ranks = mock(PostRankRepository.class);
    private final PostRankProperties props = new PostRankProperties(1.0, 1.5, 0.6, 1.2, 60, 6, 2.0, 0.5, 5, 14, 2, 12, 30, 300000);
    private final SchedulerLock lock = mock(SchedulerLock.class);
    private final TransactionTemplate tx = new TransactionTemplate(mock(PlatformTransactionManager.class));

    private Post post(long id) {
        Post p = new Post();
        p.setId(id);
        p.setAuthorId(1L);
        p.setCreatedAt(Instant.now().minus(Duration.ofHours(2)));
        p.setLikeCount(3);
        return p;
    }

    private PostRankService service(long zeroOldIntervalMs) {
        return new PostRankService(posts, ranks, props, lock, tx, zeroOldIntervalMs);
    }

    @Test
    void recentLikesAreReadOnceNotPerBatch() {
        List<Post> batch1 = new ArrayList<>();
        for (long i = 1; i <= 500; i++) {
            batch1.add(post(i));
        }
        AtomicInteger calls = new AtomicInteger();
        when(posts.scoreBatch(any(Instant.class), anyLong(), any(Pageable.class))).thenAnswer(inv -> {
            int n = calls.incrementAndGet();
            return n == 1 ? batch1 : n == 2 ? List.of(post(501)) : List.of();
        });
        when(ranks.recentLikesSince(any(Instant.class))).thenReturn(List.<Object[]>of(new Object[] {1L, 4L}));

        service(0).recompute();

        verify(ranks, times(1)).recentLikesSince(any(Instant.class));
        verify(ranks, never()).recentLikes(anyCollection(), any(Instant.class));
    }

    @Test
    void zeroOldRunsOnFirstScheduledRoundThenOnlyAfterTheInterval() {
        when(posts.scoreBatch(any(Instant.class), anyLong(), any(Pageable.class))).thenReturn(List.of());
        PostRankService s = service(Duration.ofHours(1).toMillis());

        s.recompute(false);
        s.recompute(false);
        s.recompute(false);
        verify(ranks, times(1)).zeroOld(any(Instant.class));

        s.recompute(true); // elle tetikleme / test: her zaman
        verify(ranks, times(2)).zeroOld(any(Instant.class));
        assertEquals(Duration.ofHours(1).toMillis(), s.zeroOldIntervalMs());
    }

    @Test
    void zeroIntervalKeepsTodaysBehaviourOfZeroingEveryRound() {
        when(posts.scoreBatch(any(Instant.class), anyLong(), any(Pageable.class))).thenReturn(List.of());
        PostRankService s = service(0);
        s.recompute(false);
        s.recompute(false);
        verify(ranks, times(2)).zeroOld(any(Instant.class));
    }
}
