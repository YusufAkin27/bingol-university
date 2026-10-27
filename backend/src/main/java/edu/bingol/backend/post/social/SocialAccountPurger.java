package edu.bingol.backend.post.social;

import edu.bingol.backend.post.follow.FollowService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hesap silme (KVKK) icin sosyal veri: kaydedilenler, etiketlenmeler, takipler (+ karsi sayaclar), hikayeler ve
 * goruntuleme kayitlari. PostAccountPurger.purge icinden cagrilir; hikaye medya baytlari oradaki
 * PostMediaService.purgeUser ile kalkar (once calisir).
 */
@Component
public class SocialAccountPurger {

    private final JdbcTemplate jdbc;
    private final FollowService follows;

    public SocialAccountPurger(JdbcTemplate jdbc, FollowService follows) {
        this.jdbc = jdbc;
        this.follows = follows;
    }

    public void purge(Long userId) {
        jdbc.update("DELETE FROM post_save WHERE user_id = ?", userId);
        jdbc.update("DELETE FROM post_mention WHERE user_id = ?", userId);
        jdbc.update("DELETE FROM story_view WHERE viewer_id = ?", userId);
        jdbc.update("DELETE FROM story_view WHERE story_id IN (SELECT id FROM story WHERE author_id = ?)", userId);
        jdbc.update("DELETE FROM story WHERE author_id = ?", userId);
        follows.purgeUser(userId);
    }
}
