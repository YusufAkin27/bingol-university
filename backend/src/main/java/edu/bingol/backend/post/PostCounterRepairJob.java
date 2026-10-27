package edu.bingol.backend.post;

import edu.bingol.backend.config.SchedulerLock;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Gece 03:30: beğeni/yorum/yanıt sayaçlarını gerçek sayımla onarır (PostgreSQL; duman betiğiyle doğrulanır). */
@Component
public class PostCounterRepairJob {

    private static final Logger log = LoggerFactory.getLogger(PostCounterRepairJob.class);

    private final JdbcTemplate jdbc;
    private final SchedulerLock lock;

    public PostCounterRepairJob(JdbcTemplate jdbc, SchedulerLock lock) {
        this.jdbc = jdbc;
        this.lock = lock;
    }

    @Scheduled(cron = "${app.post.counter-repair-cron:0 30 3 * * *}", zone = "Europe/Istanbul")
    public void scheduled() {
        try {
            lock.tryRun("post-counter-repair", Duration.ofMinutes(30), this::repair);
        } catch (RuntimeException e) {
            log.warn("Gonderi sayac onarimi basarisiz: {}", e.toString());
        }
    }

    public void repair() {
        int likes = jdbc.update("UPDATE post p SET like_count = (SELECT COUNT(*) FROM post_like l WHERE l.post_id = p.id) "
                + "WHERE p.like_count <> (SELECT COUNT(*) FROM post_like l WHERE l.post_id = p.id)");
        int comments = jdbc.update("UPDATE post p SET comment_count = (SELECT COUNT(*) FROM post_comment c "
                + "WHERE c.post_id = p.id AND c.deleted_at IS NULL) WHERE p.comment_count <> (SELECT COUNT(*) "
                + "FROM post_comment c WHERE c.post_id = p.id AND c.deleted_at IS NULL)");
        int replies = jdbc.update("UPDATE post_comment c SET reply_count = (SELECT COUNT(*) FROM post_comment r "
                + "WHERE r.parent_id = c.id AND r.deleted_at IS NULL) WHERE c.reply_count <> (SELECT COUNT(*) "
                + "FROM post_comment r WHERE r.parent_id = c.id AND r.deleted_at IS NULL)");
        if (likes + comments + replies > 0) {
            log.info("Gonderi sayaclari onarildi: begeni={}, yorum={}, yanit={}", likes, comments, replies);
        }
    }
}
