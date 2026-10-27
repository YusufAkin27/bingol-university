package edu.bingol.backend.post;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/** Saatlik popülerlik puanı güncellemesi (son 7 gün); eski gönderilerin puanı sıfırlanır. Servis sözleşmesi: exception sızdırmaz. */
@Component
public class PostScoreJob {

    private static final Logger log = LoggerFactory.getLogger(PostScoreJob.class);
    private static final int BATCH = 500;

    private final PostRepository posts;
    private final SchedulerLock lock;
    private final TransactionTemplate tx;

    public PostScoreJob(PostRepository posts, SchedulerLock lock, TransactionTemplate tx) {
        this.posts = posts;
        this.lock = lock;
        this.tx = tx;
    }

    @Scheduled(cron = "${app.post.score-cron:0 5 * * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        try {
            lock.tryRun("post-score", Duration.ofMinutes(20), this::recompute);
        } catch (RuntimeException e) {
            log.warn("Gonderi puan isi basarisiz: {}", e.toString());
        }
    }

    /** Test ve elle tetikleme için kilitsiz çekirdek. */
    public void recompute() {
        Instant now = Instant.now();
        Instant since = now.minus(PostService.POPULAR_WINDOW);
        tx.executeWithoutResult(s -> posts.zeroOldScores(since));
        long after = 0;
        while (true) {
            final long cursor = after;
            Long last = tx.execute(s -> {
                List<Post> batch = posts.scoreBatch(since, cursor, PageRequest.of(0, BATCH));
                for (Post p : batch) {
                    double ageH = Duration.between(p.getCreatedAt(), now).toSeconds() / 3600.0;
                    p.setScore(PostScore.compute(p.getLikeCount(), p.getCommentCount(), ageH));
                }
                posts.saveAll(batch);
                return batch.size() < BATCH ? null : batch.get(batch.size() - 1).getId();
            });
            if (last == null) {
                return;
            }
            after = last;
        }
    }
}
