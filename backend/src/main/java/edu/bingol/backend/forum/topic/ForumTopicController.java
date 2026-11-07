package edu.bingol.backend.forum.topic;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.topic.ForumTopicDtos.CreateTopicRequest;
import edu.bingol.backend.forum.topic.ForumTopicDtos.FollowState;
import edu.bingol.backend.forum.topic.ForumTopicDtos.LikeState;
import edu.bingol.backend.forum.topic.ForumTopicDtos.NotificationsRequest;
import edu.bingol.backend.forum.topic.ForumTopicDtos.NotificationsState;
import edu.bingol.backend.forum.topic.ForumTopicDtos.SaveState;
import edu.bingol.backend.forum.topic.ForumTopicDtos.UpdateTopicRequest;
import edu.bingol.backend.forum.topic.dto.ForumPage;
import edu.bingol.backend.forum.topic.dto.TopicSummary;
import edu.bingol.backend.forum.topic.dto.TopicView;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Forum konu uclari: yalniz HTTP eslemesi + hiz siniri; kurallar servislerde (sozlesme: docs/FORUM_API.md). */
@RestController
@RequestMapping("/api/forum/topics")
public class ForumTopicController {

    private final ForumTopicService service;
    private final ForumFeedService feed;
    private final ForumReactionService reactions;
    private final RateLimiter limiter;

    public ForumTopicController(ForumTopicService service, ForumFeedService feed, ForumReactionService reactions,
                                RateLimiter limiter) {
        this.service = service;
        this.feed = feed;
        this.reactions = reactions;
        this.limiter = limiter;
    }

    @GetMapping
    public ForumPage<TopicSummary> list(@RequestParam(required = false) String sort,
                                        @RequestParam(required = false) Long categoryId,
                                        @RequestParam(required = false) String cursor,
                                        @RequestParam(required = false) Integer size) {
        Long uid = CurrentUser.id();
        limiter.check("forum:read:" + uid, 120, Duration.ofMinutes(1));
        return feed.feed(uid, ForumFeedService.parseSort(sort), categoryId, cursor, size);
    }

    private edu.bingol.backend.common.WriteMetrics metrics;

    @org.springframework.beans.factory.annotation.Autowired(required = false)
    void setMetrics(edu.bingol.backend.common.WriteMetrics metrics) {
        this.metrics = metrics;
    }

    /** Kullanici basina saatte 5 konu; ayni Idempotency-Key ile tekrar ayni konuyu doner. */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public TopicView create(@RequestBody CreateTopicRequest req,
                            @RequestHeader(value = "Idempotency-Key", required = false) String idemKey) {
        Long uid = CurrentUser.id();
        limiter.check("forum:topic:create:" + uid, 5, Duration.ofHours(1));
        return edu.bingol.backend.common.WriteMetrics.of(metrics, "forum.topic.create", () -> service.create(uid, req, idemKey));
    }

    @GetMapping("/{id}")
    public TopicView get(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:read:" + uid, 120, Duration.ofMinutes(1));
        return service.get(uid, id);
    }

    @PatchMapping("/{id}")
    public TopicView update(@PathVariable Long id, @RequestBody UpdateTopicRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("forum:topic:write:" + uid, 30, Duration.ofMinutes(1));
        return service.update(uid, id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:topic:write:" + uid, 30, Duration.ofMinutes(1));
        service.delete(uid, id);
    }

    @PutMapping("/{id}/like")
    public LikeState like(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:like:" + uid, 120, Duration.ofMinutes(1));
        return reactions.like(uid, id);
    }

    @DeleteMapping("/{id}/like")
    public LikeState unlike(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:like:" + uid, 120, Duration.ofMinutes(1));
        return reactions.unlike(uid, id);
    }

    @PutMapping("/{id}/bookmark")
    public SaveState save(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:save:" + uid, 120, Duration.ofMinutes(1));
        return reactions.save(uid, id);
    }

    @DeleteMapping("/{id}/bookmark")
    public SaveState unsave(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:save:" + uid, 120, Duration.ofMinutes(1));
        return reactions.unsave(uid, id);
    }

    @PutMapping("/{id}/follow")
    public FollowState follow(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:follow:" + uid, 60, Duration.ofMinutes(1));
        return reactions.follow(uid, id);
    }

    @DeleteMapping("/{id}/follow")
    public FollowState unfollow(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("forum:follow:" + uid, 60, Duration.ofMinutes(1));
        return reactions.unfollow(uid, id);
    }

    @PutMapping("/{id}/notifications")
    public NotificationsState notifications(@PathVariable Long id, @RequestBody NotificationsRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("forum:follow:" + uid, 60, Duration.ofMinutes(1));
        return reactions.setNotifications(uid, id, req == null || req.enabled() == null || req.enabled());
    }
}
