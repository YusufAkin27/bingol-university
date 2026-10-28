package edu.bingol.backend.post.social;

import edu.bingol.backend.post.follow.FollowService;
import org.springframework.stereotype.Component;

/**
 * Hesap silme (KVKK) icin sosyal veri: takipler (+ karsi sayaclar). PostAccountPurger.purge icinden cagrilir.
 */
@Component
public class SocialAccountPurger {

    private final FollowService follows;

    public SocialAccountPurger(FollowService follows) {
        this.follows = follows;
    }

    public void purge(Long userId) {
        follows.purgeUser(userId);
    }
}
