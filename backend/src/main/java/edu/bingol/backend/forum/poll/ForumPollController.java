package edu.bingol.backend.forum.poll;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.forum.poll.spi.PollView;
import java.time.Duration;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Forum konu anketi uclari: yalniz HTTP eslemesi + hiz siniri; kurallar {@link ForumPollVoteService}'te. */
@RestController
@RequestMapping("/api/forum/topics/{topicId}/poll")
public class ForumPollController {

    /** Oy istegi. */
    public record VoteRequest(Long optionId) {}

    private final ForumPollVoteService votes;
    private final RateLimiter limiter;

    public ForumPollController(ForumPollVoteService votes, RateLimiter limiter) {
        this.votes = votes;
        this.limiter = limiter;
    }

    /** Konunun anketi (sonuclar herkese gorunur). */
    @GetMapping
    public PollView get(@PathVariable Long topicId) {
        return votes.get(topicId, CurrentUser.id());
    }

    /** Oy ver ya da (izin varsa) degistir. Ayni secenege tekrar oy idempotenttir. */
    @PutMapping("/vote")
    public PollView vote(@PathVariable Long topicId, @RequestBody VoteRequest req) {
        Long me = CurrentUser.id();
        limiter.check("forum:poll:vote:" + me, 60, Duration.ofMinutes(1));
        if (req == null || req.optionId() == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "FORUM_POLL_OPTION_REQUIRED", "Bir seçenek seçin.");
        }
        return votes.vote(topicId, me, req.optionId());
    }

    /** Oyu geri al (yalniz oy degistirmeye izin veren acik anket). */
    @DeleteMapping("/vote")
    public PollView retract(@PathVariable Long topicId) {
        Long me = CurrentUser.id();
        limiter.check("forum:poll:vote:" + me, 60, Duration.ofMinutes(1));
        return votes.retract(topicId, me);
    }
}
