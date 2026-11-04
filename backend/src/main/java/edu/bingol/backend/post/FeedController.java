package edu.bingol.backend.post;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.post.PostDtos.FeedPage;
import edu.bingol.backend.post.PostDtos.SeenRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Keşfet akışı. Kapsamlar: foryou (kişiselleştirilmiş, varsayılan) | popular (= top; popülerlik puanı) | latest | following
 * (| department). size: 0 = kapsam varsayılanı. Ayrıca Reels (yalnız video, öneri algoritması) ve "görüldü" bildirimi.
 */
@RestController
@RequestMapping("/api/feed")
public class FeedController {

    private final PostService service;
    private final RateLimiter limiter;

    public FeedController(PostService service, RateLimiter limiter) {
        this.service = service;
        this.limiter = limiter;
    }

    @GetMapping
    public FeedPage feed(@RequestParam(defaultValue = "foryou") String scope,
                         @RequestParam(required = false) String cursor, @RequestParam(defaultValue = "0") int size) {
        Long uid = CurrentUser.id();
        limiter.check("post:read:" + uid, 120, Duration.ofMinutes(1));
        return service.feed(uid, unify(scope), cursor, size);
    }

    /**
     * Dikey tam ekran video akışı (öneri algoritması: ReelsService). replay=true: "Tekrar izle" (geçmişi yok sayan yeni oturum;
     * yalnız ilk çağrıda, cursor'suz). İçerik tükenince exhausted=true.
     */
    @GetMapping("/reels")
    public FeedPage reels(@RequestParam(required = false) String cursor, @RequestParam(defaultValue = "0") int size,
                          @RequestParam(defaultValue = "false") boolean replay) {
        Long uid = CurrentUser.id();
        limiter.check("post:read:" + uid, 120, Duration.ofMinutes(1));
        return service.reels(uid, cursor, size, replay);
    }

    /** Ekranda görünen gönderi/reel kimlikleri (toplu, en çok 100); görülmüş kümesine yazılır. */
    @PostMapping("/seen")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void seen(@Valid @RequestBody SeenRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("feed:seen:" + uid, 60, Duration.ofMinutes(1));
        service.markSeen(uid, req.ids());
    }

    /**
     * Kapsamlar: foryou (Senin İçin, varsayılan) | popular (popülerlik puanı; eski `top` takma adı) | latest (en yeni) |
     * following | department. Boş = foryou; geçersiz değer 400 FEED_SCOPE_INVALID.
     */
    static String unify(String scope) {
        if (scope == null || scope.isBlank()) {
            return "foryou";
        }
        String s = scope.toLowerCase(Locale.ROOT);
        return "top".equals(s) ? "popular" : s;
    }
}
