package edu.bingol.backend.post.save;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.save.PostSaveService.SaveState;
import java.time.Duration;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Kaydetme uclari: yalniz HTTP eslemesi + hiz siniri. Sabit yol "saved", {id} eslemesinden onceliklidir. */
@RestController
@RequestMapping("/api/posts")
public class PostSaveController {

    private final PostSaveService service;
    private final RateLimiter limiter;

    public PostSaveController(PostSaveService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping("/saved")
    public FeedPage saved(@RequestParam(required = false) String cursor, @RequestParam(defaultValue = "20") int size) {
        Long uid = CurrentUser.id();
        limiter.check("post:read:" + uid, 120, Duration.ofMinutes(1));
        return service.saved(uid, cursor, size);
    }

    @PutMapping("/{id}/save")
    public SaveState save(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("post:save:" + uid, 120, Duration.ofMinutes(1));
        return service.save(uid, id);
    }

    @DeleteMapping("/{id}/save")
    public SaveState unsave(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("post:save:" + uid, 120, Duration.ofMinutes(1));
        return service.unsave(uid, id);
    }
}
