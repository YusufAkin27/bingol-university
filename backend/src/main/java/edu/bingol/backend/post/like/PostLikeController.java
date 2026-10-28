package edu.bingol.backend.post.like;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.like.PostLikeDtos.LikeState;
import edu.bingol.backend.post.like.PostLikeDtos.LikersPage;
import java.time.Duration;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/posts/{id}")
public class PostLikeController {

    private final PostLikeService service;
    private final RateLimiter limiter;

    public PostLikeController(PostLikeService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @PutMapping("/like")
    public LikeState like(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("post:like:" + uid, 120, Duration.ofMinutes(1));
        return service.like(uid, id);
    }

    @DeleteMapping("/like")
    public LikeState unlike(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("post:like:" + uid, 120, Duration.ofMinutes(1));
        return service.unlike(uid, id);
    }

    // GET /likes (begenenler listesi) kaldirildi (sade Kesfet sozlesmesi).
}
