package edu.bingol.backend.post.story;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.story.AdminStoryService.StoryPage;
import edu.bingol.backend.post.story.AdminStoryService.StoryRow;
import jakarta.validation.constraints.Size;
import java.time.Duration;
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

/** Yonetici hikaye moderasyonu (`/api/admin/**` yalniz ADMIN; yazmalar denetlenir). */
@RestController
@RequestMapping("/api/admin/stories")
public class AdminStoryController {

    public record ReasonRequest(@Size(max = 300) String reason) {}

    private final AdminStoryService service;
    private final StoryService stories;
    private final RateLimiter limiter;

    public AdminStoryController(AdminStoryService service, StoryService stories, RateLimiter limiter) {
        this.service = service;
        this.stories = stories;
        this.limiter = limiter;
    }

    /** Imlec = hikaye id (en yeni once); q = yazar adi/e-postasi; hidden = gizli/gorunur suzgeci. */
    @GetMapping
    public StoryPage list(@RequestParam(required = false) Long cursor, @RequestParam(defaultValue = "20") int size,
                          @RequestParam(required = false) String q, @RequestParam(required = false) Boolean hidden) {
        limit();
        return service.list(cursor, size, q, hidden);
    }

    @PostMapping("/{id}/hide")
    public StoryRow hide(@PathVariable long id, @RequestBody(required = false) ReasonRequest body) {
        limit();
        return service.hide(id, body == null ? null : body.reason());
    }

    @PostMapping("/{id}/unhide")
    public StoryRow unhide(@PathVariable long id) {
        limit();
        return service.unhide(id);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable long id) {
        limit();
        stories.delete(CurrentUser.id(), id, true);
    }

    private void limit() {
        limiter.check("adminstories:" + CurrentUser.id(), 120, Duration.ofMinutes(1));
    }
}
