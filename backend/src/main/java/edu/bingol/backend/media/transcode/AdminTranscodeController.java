package edu.bingol.backend.media.transcode;

import edu.bingol.backend.common.RateLimiter;
import java.time.Duration;
import java.time.Instant;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Video donusturme kuyrugu sayaclari (yalniz ADMIN: /api/admin/** SecurityConfig'te ADMIN). Yonetim paneli
 * "Operasyon > Kuyruklar" sekmesi okur; kuyrugu degistirmez.
 */
@RestController
@RequestMapping("/api/admin/ops/transcode")
public class AdminTranscodeController {

    private final PostMediaTranscodeRepository repo;
    private final TranscodeProperties props;
    private final RateLimiter limiter;

    public AdminTranscodeController(PostMediaTranscodeRepository repo, TranscodeProperties props, RateLimiter limiter) {
        this.repo = repo;
        this.props = props;
        this.limiter = limiter;
    }

    /** enabled=false: ffmpeg donusumu kapali, videolar oldugu gibi saklanir (sayaclar yine de okunur). */
    public record TranscodeStats(boolean enabled, long pending, long processing, long failed, long doneLast24h) {}

    @GetMapping("/stats")
    public TranscodeStats stats() {
        limiter.check("admin:ops:transcode:" + principal(), 60, Duration.ofMinutes(1));
        return new TranscodeStats(props.enabled(), repo.countByStatus("PENDING"), repo.countByStatus("PROCESSING"),
                repo.countByStatus("FAILED"), repo.countDoneSince(Instant.now().minus(Duration.ofHours(24))));
    }

    /** Basic auth yoneticisinde sayisal kimlik yoktur: ad kullanilir. */
    private static String principal() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a == null ? "anon" : String.valueOf(a.getPrincipal());
    }
}
