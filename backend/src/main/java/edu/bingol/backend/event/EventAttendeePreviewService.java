package edu.bingol.backend.event;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.dto.EventDtos.AttendeeAvatar;
import edu.bingol.backend.event.dto.EventDtos.AttendeePreview;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.privacy.AvatarVisibility;
import edu.bingol.backend.profile.privacy.AvatarVisibility.Field;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Katilimci listesi organizatore kisitli kalir; bu servis etkinligi gorebilen herkese yalnizca sayilar ve
 * gizlilik ayari izin veren birkac avatar verir (organizator listesindeki kimlik bilgisi sizmaz).
 */
@Service
public class EventAttendeePreviewService {

    static final int MAX_AVATARS = 8;
    /** Gizli/engelli/avatarsiz kisiler elendikten sonra 8'i doldurabilmek icin aday havuzu. */
    static final int CANDIDATES = 40;

    private final EventService events;
    private final EventRsvpRepository rsvps;
    private final CommunityService communities;
    private final AvatarVisibility visibility;
    private final BlockService blocks;

    public EventAttendeePreviewService(EventService events, EventRsvpRepository rsvps, CommunityService communities,
                                       AvatarVisibility visibility, BlockService blocks) {
        this.events = events;
        this.rsvps = rsvps;
        this.communities = communities;
        this.visibility = visibility;
        this.blocks = blocks;
    }

    @Transactional(readOnly = true)
    public AttendeePreview preview(Actor a, Long eventId) {
        UserEvent e = events.loadVisible(a, eventId);
        long interested = rsvps.countByEventIdAndStatus(eventId, EventRsvp.Status.INTERESTED);
        List<Long> candidates = rsvps.page(eventId, EventRsvp.Status.GOING, 0L, PageRequest.of(0, CANDIDATES))
                .stream().map(EventRsvp::getUserId).toList();
        return new AttendeePreview(e.getGoingCount(), interested, avatars(a, candidates));
    }

    private List<AttendeeAvatar> avatars(Actor viewer, List<Long> candidates) {
        if (candidates.isEmpty()) {
            return List.of();
        }
        Set<Long> hidden = blocks.hiddenFrom(viewer.id());
        Set<Long> allowed = visibility.visibleOwners(viewer.id(), candidates, Field.AVATAR);
        Map<Long, User> users = communities.usersById(candidates);
        return candidates.stream()
                .filter(id -> !hidden.contains(id) && allowed.contains(id))
                .map(users::get)
                .filter(u -> u != null && u.getStatus() == UserStatus.ACTIVE && u.getAvatarUrl() != null)
                .limit(MAX_AVATARS)
                .map(u -> new AttendeeAvatar(u.getId(), u.getDisplayName(), u.getAvatarUrl()))
                .toList();
    }
}
