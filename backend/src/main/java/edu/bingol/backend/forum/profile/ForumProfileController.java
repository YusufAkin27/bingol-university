package edu.bingol.backend.forum.profile;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.profile.ForumProfileService.ProfilePage;
import edu.bingol.backend.forum.profile.ForumProfileService.SavedItem;
import edu.bingol.backend.forum.profile.ForumProfileService.Summary;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import java.time.Duration;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Forum profil / etkinlik uclari (giris gerekli). {@code /me/*}: kendi icerigim (anonim dahil);
 * {@code /users/{id}/*}: baskasinin YALNIZ herkese acik (anonim olmayan) forum faaliyeti.
 */
@RestController
@RequestMapping("/api/forum")
public class ForumProfileController {

    private final ForumProfileService profile;
    private final RateLimiter limiter;

    public ForumProfileController(ForumProfileService profile, RateLimiter limiter) {
        this.profile = profile;
        this.limiter = limiter;
    }

    private Long uid() {
        Long uid = CurrentUser.id();
        limiter.check("fprof:" + uid, 120, Duration.ofMinutes(1));
        return uid;
    }

    @GetMapping("/me/topics")
    public ProfilePage<TopicSummary> myTopics(@RequestParam(required = false) String cursor,
                                              @RequestParam(required = false) Integer size) {
        return profile.myTopics(uid(), cursor, size);
    }

    @GetMapping("/me/comments")
    public ProfilePage<Map<String, Object>> myComments(@RequestParam(required = false) String cursor,
                                                  @RequestParam(required = false) Integer size) {
        return profile.myComments(uid(), cursor, size);
    }

    @GetMapping("/me/saved")
    public ProfilePage<SavedItem> saved(@RequestParam(required = false) String cursor,
                                        @RequestParam(required = false) Integer size) {
        return profile.saved(uid(), cursor, size);
    }

    @GetMapping("/me/following")
    public ProfilePage<TopicSummary> following(@RequestParam(required = false) String cursor,
                                               @RequestParam(required = false) Integer size) {
        return profile.following(uid(), cursor, size);
    }

    @GetMapping("/users/{id}/topics")
    public ProfilePage<TopicSummary> userTopics(@PathVariable Long id, @RequestParam(required = false) String cursor,
                                                @RequestParam(required = false) Integer size) {
        return profile.userTopics(uid(), id, cursor, size);
    }

    @GetMapping("/users/{id}/comments")
    public ProfilePage<Map<String, Object>> userComments(@PathVariable Long id,
                                                    @RequestParam(required = false) String cursor,
                                                    @RequestParam(required = false) Integer size) {
        return profile.userComments(uid(), id, cursor, size);
    }

    @GetMapping("/users/{id}/summary")
    public Summary userSummary(@PathVariable Long id) {
        return profile.userSummary(uid(), id);
    }
}
