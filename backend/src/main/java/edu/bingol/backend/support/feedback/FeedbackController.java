package edu.bingol.backend.support.feedback;

import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.support.feedback.FeedbackDtos.AdminFeedbackPage;
import edu.bingol.backend.support.feedback.FeedbackDtos.CreateFeedbackRequest;
import edu.bingol.backend.support.feedback.FeedbackDtos.FeedbackPage;
import edu.bingol.backend.support.feedback.FeedbackDtos.FeedbackView;
import edu.bingol.backend.support.feedback.FeedbackDtos.SuggestionPage;
import edu.bingol.backend.support.feedback.FeedbackDtos.UpdateFeedbackRequest;
import jakarta.validation.Valid;
import java.time.Duration;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Geri bildirim (hata, oneri, sikayet, tesekkur) ve herkese acik oneri panosu. */
@RestController
@RequestMapping("/api")
public class FeedbackController {

    private final FeedbackService feedback;
    private final RateLimiter limiter;

    public FeedbackController(FeedbackService feedback, RateLimiter limiter) {
        this.feedback = feedback;
        this.limiter = limiter;
    }

    /** Kullanici basina gunde 10 geri bildirim. */
    @PostMapping("/feedback")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Long> create(@Valid @RequestBody CreateFeedbackRequest r) {
        Long uid = CurrentUser.id();
        limiter.check("feedback:user:" + uid, 10, Duration.ofDays(1));
        return Map.of("id", feedback.create(uid, r).getId());
    }

    @GetMapping("/feedback/mine")
    public FeedbackPage mine(@RequestParam(required = false) Long cursor, @RequestParam(defaultValue = "20") int size) {
        return feedback.mine(CurrentUser.id(), cursor, size);
    }

    /** Yonetici onayli oneriler. sort=top|new, sayfa tabanli (oy sirasi imece uygun degildir). */
    @GetMapping("/suggestions")
    public SuggestionPage board(@RequestParam(defaultValue = "top") String sort,
                                @RequestParam(defaultValue = "0") int page,
                                @RequestParam(defaultValue = "20") int size) {
        return feedback.board(CurrentUser.id(), sort, page, size);
    }

    @PutMapping("/suggestions/{id}/vote")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void vote(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("vote:user:" + uid, 60, Duration.ofHours(1));
        feedback.vote(uid, id);
    }

    @DeleteMapping("/suggestions/{id}/vote")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unvote(@PathVariable Long id) {
        Long uid = CurrentUser.id();
        limiter.check("vote:user:" + uid, 60, Duration.ofHours(1)); // oy verme ile ayni kova (T-060)
        feedback.unvote(uid, id);
    }

    // --- yonetici ---

    @GetMapping("/admin/feedback")
    public AdminFeedbackPage adminList(@RequestParam(required = false) Feedback.Status status,
                                       @RequestParam(required = false) Feedback.Category category,
                                       @RequestParam(required = false) Long cursor,
                                       @RequestParam(defaultValue = "20") int size) {
        return feedback.adminList(status, category, cursor, size);
    }

    @PatchMapping("/admin/feedback/{id}")
    public FeedbackView adminUpdate(@PathVariable Long id, @Valid @RequestBody UpdateFeedbackRequest r) {
        return FeedbackView.of(feedback.adminUpdate(id, r));
    }
}
