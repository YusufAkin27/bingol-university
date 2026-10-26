package edu.bingol.backend.moderation;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.moderation.dto.ModerationDtos.AppealRequest;
import edu.bingol.backend.moderation.dto.ModerationDtos.AppealView;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Kullanicinin kendi icerigi icin moderasyon itirazi. */
@RestController
@RequestMapping("/api/appeals")
public class AppealController {

    private final AppealService appeals;
    private final RateLimiter limiter;

    public AppealController(AppealService appeals, RateLimiter limiter) {
        this.appeals = appeals;
        this.limiter = limiter;
    }

    /** Gizlenen kendi icerigine itiraz (gunde 5). Baskasinin/gizli olmayan icerik: 404. */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Long> create(@Valid @RequestBody AppealRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("appeal:user:" + uid, 5, Duration.ofDays(1));
        return Map.of("id", appeals.create(uid, r.targetType(), r.targetId(), r.message()).getId());
    }

    @GetMapping("/mine")
    public List<AppealView> mine() {
        return appeals.mine(CurrentUser.id()).stream().map(AppealView::of).toList();
    }
}
