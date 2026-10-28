package edu.bingol.backend.post.story;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.story.StoryDtos.CreateRequest;
import edu.bingol.backend.post.story.StoryDtos.StoryView;
import edu.bingol.backend.post.story.StoryDtos.TrayItem;
import edu.bingol.backend.post.story.StoryDtos.ViewerPage;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

// Devre disi: sade gonderi sozlesmesi (uc RemovedFeatureController ile 410 FEATURE_REMOVED doner). Geri almak icin @RestController ekleyin ve 410 eslemesini kaldirin.
@RequestMapping("/api")
public class StoryController {

    private final StoryService service;
    private final RateLimiter limiter;

    public StoryController(StoryService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @PostMapping("/stories")
    @ResponseStatus(HttpStatus.CREATED)
    public StoryView create(@RequestBody CreateRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("story:create:" + uid, 20, Duration.ofHours(1));
        return service.create(uid, req);
    }

    @GetMapping("/stories/tray")
    public List<TrayItem> tray() {
        return service.tray(read());
    }

    @GetMapping("/users/{id}/stories")
    public List<StoryView> ofUser(@PathVariable Long id) {
        return service.ofUser(read(), id);
    }

    @PostMapping("/stories/{id}/view")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void view(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("story:view:" + uid, 300, Duration.ofMinutes(1));
        service.markViewed(uid, id);
    }

    @GetMapping("/stories/{id}/viewers")
    public ViewerPage viewers(@PathVariable Long id, @RequestParam(required = false) String cursor,
                              @RequestParam(defaultValue = "30") int size) {
        return service.viewers(read(), id, cursor, size);
    }

    @DeleteMapping("/stories/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("story:delete:" + uid, 60, Duration.ofMinutes(1));
        service.delete(uid, id, CurrentUser.isAdmin());
    }

    private Long read() {
        Long uid = CurrentUser.id();
        limiter.check("story:read:" + uid, 120, Duration.ofMinutes(1));
        return uid;
    }
}
