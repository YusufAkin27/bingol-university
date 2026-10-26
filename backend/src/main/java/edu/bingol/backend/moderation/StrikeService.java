package edu.bingol.backend.moderation;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Tekrarlayan ihlal takibi: kullanici basina cozulmus ihlal sayisi; esik asilinca yoneticiye askiya alma onerisi. */
@Service
public class StrikeService {

    private final ModerationStrikeRepository strikes;
    private final SuspendRecommendationRepository recommendations;
    private final ModerationProperties props;
    private final ModerationNotifier notifier;
    private final UserModerationService userModeration;
    private final UserRepository users;

    public StrikeService(ModerationStrikeRepository strikes, SuspendRecommendationRepository recommendations,
                         ModerationProperties props, ModerationNotifier notifier, UserModerationService userModeration,
                         UserRepository users) {
        this.strikes = strikes;
        this.recommendations = recommendations;
        this.props = props;
        this.notifier = notifier;
        this.userModeration = userModeration;
        this.users = users;
    }

    /** Ihlal kaydi ekler; esik asildiysa (ve acik oneri yoksa, kullanici hala aktifse) oneri olusturur. */
    @Transactional
    public void record(Long userId, Report report, Report.Resolution resolution) {
        ModerationStrike s = new ModerationStrike();
        s.setUserId(userId);
        s.setReportId(report.getId());
        s.setTargetType(report.getTargetType());
        s.setTargetId(report.getTargetId());
        s.setResolution(resolution);
        strikes.save(s);
        recommendIfNeeded(userId);
    }

    @Transactional
    public void recommendIfNeeded(Long userId) {
        int threshold = props.strikeSuspendThreshold();
        if (threshold <= 0) {
            return;
        }
        Instant since = Instant.now().minus(Duration.ofDays(props.strikeWindowDays()));
        long count = strikes.countByUserIdAndRevokedAtIsNullAndCreatedAtAfter(userId, since);
        if (count < threshold || recommendations.existsByUserIdAndStatus(userId, SuspendRecommendation.Status.OPEN)) {
            return;
        }
        boolean active = users.findById(userId).map(u -> u.getStatus() == UserStatus.ACTIVE).orElse(false);
        if (!active) {
            return;
        }
        SuspendRecommendation r = new SuspendRecommendation();
        r.setUserId(userId);
        r.setStrikeCount((int) count);
        recommendations.save(r);
        notifier.adminRecommendation(userId, (int) count);
    }

    /** Itiraz kabul: hedefe bagli ihlaller sayilmaz. */
    @Transactional
    public void revokeForTarget(ReportTargetType type, Long targetId) {
        strikes.revokeForTarget(type, targetId, Instant.now());
    }

    @Transactional(readOnly = true)
    public List<SuspendRecommendation> page(SuspendRecommendation.Status status, Long cursor, int size) {
        return recommendations.page(status, cursor, PageRequest.of(0, size + 1));
    }

    /** Oneriyi kabul = kullaniciyi askiya al. */
    @Transactional
    public void accept(Long id, Long adminId) {
        SuspendRecommendation r = open(id);
        userModeration.suspend(r.getUserId(), "Tekrarlayan ihlal (" + r.getStrikeCount() + ")");
        r.setStatus(SuspendRecommendation.Status.ACCEPTED);
        r.setDecidedBy(adminId);
        r.setDecidedAt(Instant.now());
    }

    @Transactional
    public void dismiss(Long id, Long adminId) {
        SuspendRecommendation r = open(id);
        r.setStatus(SuspendRecommendation.Status.DISMISSED);
        r.setDecidedBy(adminId);
        r.setDecidedAt(Instant.now());
    }

    public long strikeCount(Long userId) {
        return strikes.countByUserIdAndRevokedAtIsNull(userId);
    }

    public User userOf(Long id) {
        return users.findById(id).orElse(null);
    }

    private SuspendRecommendation open(Long id) {
        SuspendRecommendation r = recommendations.findById(id).orElseThrow(() ->
                new ApiException(HttpStatus.NOT_FOUND, "RECOMMENDATION_NOT_FOUND", "Öneri bulunamadı."));
        if (r.getStatus() != SuspendRecommendation.Status.OPEN) {
            throw new ApiException(HttpStatus.CONFLICT, "ALREADY_RESOLVED", "Kayıt zaten sonuçlandırılmış.");
        }
        return r;
    }
}
