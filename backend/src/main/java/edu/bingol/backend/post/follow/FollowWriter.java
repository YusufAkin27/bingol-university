package edu.bingol.backend.post.follow;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Gerçek takip kaydının ve sayaçlarının TEK yazıcı noktası (FollowService ve FollowRequestService ortak kullanır):
 * kayıt + user_follow_stats sayaçları aynı işlemde, atomik SQL ile.
 */
@Component
class FollowWriter {

    private final JdbcTemplate jdbc;

    FollowWriter(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Takip satırı yoksa ekler ve iki tarafın sayaçlarını arttırır. @return gerçekten eklendi mi */
    @Transactional
    boolean create(Long follower, Long followee) {
        int n = jdbc.update("INSERT INTO user_follow (follower_id, followee_id, created_at) SELECT ?, ?, CURRENT_TIMESTAMP "
                + "WHERE NOT EXISTS (SELECT 1 FROM user_follow WHERE follower_id = ? AND followee_id = ?)",
                follower, followee, follower, followee);
        if (n > 0) {
            ensureStats(follower);
            ensureStats(followee);
            jdbc.update("UPDATE user_follow_stats SET following_count = following_count + 1 WHERE user_id = ?", follower);
            jdbc.update("UPDATE user_follow_stats SET follower_count = follower_count + 1 WHERE user_id = ?", followee);
        }
        return n > 0;
    }

    /** Takip satırı varsa siler ve sayaçları düşürür. @return silindi mi */
    @Transactional
    boolean remove(Long follower, Long followee) {
        int n = jdbc.update("DELETE FROM user_follow WHERE follower_id = ? AND followee_id = ?", follower, followee);
        if (n > 0) {
            jdbc.update("UPDATE user_follow_stats SET following_count = CASE WHEN following_count > 0 "
                    + "THEN following_count - 1 ELSE 0 END WHERE user_id = ?", follower);
            jdbc.update("UPDATE user_follow_stats SET follower_count = CASE WHEN follower_count > 0 "
                    + "THEN follower_count - 1 ELSE 0 END WHERE user_id = ?", followee);
        }
        return n > 0;
    }

    private void ensureStats(Long uid) {
        try {
            jdbc.update("INSERT INTO user_follow_stats (user_id, follower_count, following_count) SELECT ?, 0, 0 "
                    + "WHERE NOT EXISTS (SELECT 1 FROM user_follow_stats WHERE user_id = ?)", uid, uid);
        } catch (DuplicateKeyException ignored) {
            // eş zamanlı ilk takip: satır başka işlemce açıldı
        }
    }
}
