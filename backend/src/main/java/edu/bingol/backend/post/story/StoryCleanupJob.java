package edu.bingol.backend.post.story;

import edu.bingol.backend.config.SchedulerLock;
import edu.bingol.backend.post.media.PostMediaService;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Suresi dolan hikayeleri (bitisten {@code retention-hours}, varsayilan 24 saat sonra) ve silinenleri kalici siler;
 * medya baytlari PostMediaService.removeStoryMedia ile kalkar. Her saat :35'te (coklu ornekte SchedulerLock).
 * Hata cagirana sizmaz.
 */
@Component
public class StoryCleanupJob {

    private static final Logger log = LoggerFactory.getLogger(StoryCleanupJob.class);
    static final int BATCH = 200;
    static final int MAX_BATCHES = 10;

    private final StoryRepository stories;
    private final PostMediaService mediaService;
    private final SchedulerLock lock;
    private final Clock clock;
    private final TransactionTemplate tx;
    private final int retentionHours;

    public StoryCleanupJob(StoryRepository stories, PostMediaService mediaService, SchedulerLock lock, Clock clock,
                           TransactionTemplate tx, @Value("${app.story.retention-hours:24}") int retentionHours) {
        this.stories = stories;
        this.mediaService = mediaService;
        this.lock = lock;
        this.clock = clock;
        this.tx = tx;
        this.retentionHours = Math.max(0, retentionHours);
    }

    @Scheduled(cron = "${app.story.cleanup-cron:0 35 * * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        lock.tryRun("story-cleanup", Duration.ofMinutes(20), () -> run(clock.instant()));
    }

    /** @return silinen hikaye sayisi. */
    public int run(Instant now) {
        int total = 0;
        try {
            Instant cutoff = now.minus(Duration.ofHours(retentionHours));
            for (int i = 0; i < MAX_BATCHES; i++) {
                Integer n = tx.execute(status -> {
                    List<Story> rows = stories.stale(cutoff, cutoff, PageRequest.of(0, BATCH));
                    if (rows.isEmpty()) {
                        return 0;
                    }
                    mediaService.removeStoryMedia(rows.stream().map(Story::getId).toList());
                    stories.deleteAll(rows);
                    return rows.size();
                });
                int c = n == null ? 0 : n;
                total += c;
                if (c < BATCH) {
                    break;
                }
            }
            if (total > 0) {
                log.info("Hikaye temizligi: {} hikaye silindi", total);
            }
        } catch (RuntimeException e) {
            log.warn("Hikaye temizligi basarisiz: {}", e.toString());
        }
        return total;
    }
}
