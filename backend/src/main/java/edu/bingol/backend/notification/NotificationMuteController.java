package edu.bingol.backend.notification;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.CurrentUser;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.event.UserEventRepository;
import java.time.Duration;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * Kulup / etkinlik bazinda bildirim sessize alma. Kararlar icin {@link NotificationMuteService}. Sessize almak icin
 * kulupte ACTIVE uyelik, etkinlikte var olma sarti aranir; kaldirmak her zaman serbesttir (silinmis kaynak dahil).
 */
@RestController
public class NotificationMuteController {

    /** Kullanici basina ust sinir (sinirsiz buyumeyi onler). */
    static final int MAX_MUTES = 500;

    public record MuteRequest(Boolean muted) {}

    public record MuteState(boolean muted) {}

    public record MuteList(List<Long> communities, List<Long> events) {}

    private final NotificationMuteRepository mutes;
    private final CommunityMemberRepository members;
    private final UserEventRepository events;
    private final RateLimiter limiter;

    public NotificationMuteController(NotificationMuteRepository mutes, CommunityMemberRepository members,
                                      UserEventRepository events, RateLimiter limiter) {
        this.mutes = mutes;
        this.members = members;
        this.events = events;
        this.limiter = limiter;
    }

    @GetMapping("/api/communities/{id}/notification-mute")
    public MuteState communityState(@PathVariable Long id) {
        return state(NotificationMute.COMMUNITY, id);
    }

    @PutMapping("/api/communities/{id}/notification-mute")
    @Transactional
    public MuteState communitySet(@PathVariable Long id, @RequestBody MuteRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("notifmute:user:" + uid, 60, Duration.ofMinutes(1));
        boolean on = req != null && Boolean.TRUE.equals(req.muted());
        if (on) {
            boolean active = members.findByUserIdAndCommunityIdIn(uid, List.of(id)).stream()
                    .anyMatch(m -> m.getStatus() == CommunityMember.Status.ACTIVE);
            if (!active) {
                throw new ApiException(HttpStatus.NOT_FOUND, "COMMUNITY_NOT_FOUND", "Kulüp bulunamadı.");
            }
        }
        return set(uid, NotificationMute.COMMUNITY, id, on);
    }

    @GetMapping("/api/events/{id}/notification-mute")
    public MuteState eventState(@PathVariable Long id) {
        return state(NotificationMute.EVENT, id);
    }

    @PutMapping("/api/events/{id}/notification-mute")
    @Transactional
    public MuteState eventSet(@PathVariable Long id, @RequestBody MuteRequest req) {
        Long uid = CurrentUser.id();
        limiter.check("notifmute:user:" + uid, 60, Duration.ofMinutes(1));
        boolean on = req != null && Boolean.TRUE.equals(req.muted());
        if (on && !events.existsById(id)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "EVENT_NOT_FOUND", "Etkinlik bulunamadı.");
        }
        return set(uid, NotificationMute.EVENT, id, on);
    }

    /** Sessize aldigim kulup ve etkinlik kimlikleri (en fazla 500). */
    @GetMapping("/api/me/notification-mutes")
    public MuteList mine() {
        Long uid = CurrentUser.id();
        limiter.check("notifmute:read:" + uid, 60, Duration.ofMinutes(1));
        List<NotificationMute> all = mutes.findTop500ByUserIdOrderByCreatedAtDesc(uid);
        return new MuteList(
                all.stream().filter(m -> NotificationMute.COMMUNITY.equals(m.getTargetType())).map(NotificationMute::getTargetId).toList(),
                all.stream().filter(m -> NotificationMute.EVENT.equals(m.getTargetType())).map(NotificationMute::getTargetId).toList());
    }

    private MuteState state(String type, Long id) {
        Long uid = CurrentUser.id();
        limiter.check("notifmute:read:" + uid, 60, Duration.ofMinutes(1));
        return new MuteState(mutes.existsByUserIdAndTargetTypeAndTargetId(uid, type, id));
    }

    private MuteState set(Long uid, String type, Long id, boolean on) {
        if (!on) {
            mutes.remove(uid, type, id);
            return new MuteState(false);
        }
        if (!mutes.existsByUserIdAndTargetTypeAndTargetId(uid, type, id)) {
            if (mutes.countByUserId(uid) >= MAX_MUTES) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Çok fazla sessize alma.");
            }
            mutes.save(new NotificationMute(uid, type, id));
        }
        return new MuteState(true);
    }
}
