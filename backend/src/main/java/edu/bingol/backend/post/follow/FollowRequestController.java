package edu.bingol.backend.post.follow;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.follow.FollowRequestService.CountView;
import edu.bingol.backend.post.follow.FollowRequestService.RequestItem;
import java.time.Duration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Gelen takip istekleri (gizli hesap sahibi): listele, say, kabul, reddet. Kabul/red idempotenttir ve güncel
 * {@code {count}} döner (200). İstek OLUŞTURMA/geri çekme mevcut takip uçlarındadır (FollowController).
 */
@RestController
@RequestMapping("/api/users/me/follow-requests")
public class FollowRequestController {

    private final FollowRequestService service;
    private final RateLimiter limiter;

    public FollowRequestController(FollowRequestService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping
    public CursorPage<RequestItem> list(@RequestParam(required = false) Long cursor,
                                        @RequestParam(defaultValue = "30") int size) {
        Long uid = CurrentUser.id();
        limiter.check("follow:read:" + uid, 120, Duration.ofMinutes(1));
        return service.incoming(uid, cursor, size);
    }

    @GetMapping("/count")
    public CountView count() {
        Long uid = CurrentUser.id();
        limiter.check("follow:read:" + uid, 120, Duration.ofMinutes(1));
        return new CountView(service.count(uid));
    }

    @PostMapping("/{userId}/accept")
    public CountView accept(@PathVariable Long userId) {
        Long uid = CurrentUser.id();
        limiter.check("follow-req-act:" + uid, 120, Duration.ofMinutes(1));
        return new CountView(service.accept(uid, userId));
    }

    @PostMapping("/{userId}/decline")
    public CountView decline(@PathVariable Long userId) {
        Long uid = CurrentUser.id();
        limiter.check("follow-req-act:" + uid, 120, Duration.ofMinutes(1));
        return new CountView(service.decline(uid, userId));
    }
}
