package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.dto.EventDtos.AttendeePreview;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.privacy.AvatarVisibility;
import edu.bingol.backend.profile.privacy.AvatarVisibility.Field;
import edu.bingol.backend.user.User;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Pageable;

class EventAttendeePreviewServiceTest {

    private final EventService events = mock(EventService.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final AvatarVisibility visibility = mock(AvatarVisibility.class);
    private final BlockService blocks = mock(BlockService.class);
    private final EventAttendeePreviewService svc =
            new EventAttendeePreviewService(events, rsvps, communities, visibility, blocks);

    private final Actor viewer = new Actor(1L, false);

    private User user(long id, String avatar) {
        User u = new User();
        u.setId(id);
        u.setDisplayName("U" + id);
        u.setAvatarUrl(avatar);
        return u;
    }

    private void setUp(int count, Set<Long> allowed, Set<Long> hidden, Set<Long> noAvatar) {
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setGoingCount(count);
        when(events.loadVisible(viewer, 5L)).thenReturn(e);
        when(rsvps.countByEventIdAndStatus(5L, EventRsvp.Status.INTERESTED)).thenReturn(2L);
        List<EventRsvp> going = new ArrayList<>();
        Map<Long, User> users = new HashMap<>();
        for (long i = 10; i < 10 + count; i++) {
            going.add(new EventRsvp(5L, i, EventRsvp.Status.GOING));
            users.put(i, user(i, noAvatar.contains(i) ? null : "/files/a" + i));
        }
        when(rsvps.page(eq(5L), eq(EventRsvp.Status.GOING), eq(0L), any(Pageable.class))).thenReturn(going);
        when(communities.usersById(anyCollection())).thenReturn(users);
        when(blocks.hiddenFrom(1L)).thenReturn(hidden);
        when(visibility.visibleOwners(eq(1L), anyCollection(), eq(Field.AVATAR))).thenReturn(allowed);
    }

    private Set<Long> range(long from, long to) {
        Set<Long> s = new HashSet<>();
        for (long i = from; i < to; i++) {
            s.add(i);
        }
        return s;
    }

    @Test
    void onlyPrivacyAllowedUsersAppearAndCountsAreReturned() {
        setUp(3, Set.of(10L, 12L), Set.of(), Set.of());

        AttendeePreview p = svc.preview(viewer, 5L);

        assertEquals(3, p.goingCount());
        assertEquals(2, p.interestedCount());
        assertEquals(List.of(10L, 12L), p.avatars().stream().map(a -> a.userId()).toList());
    }

    @Test
    void blockedAndAvatarlessUsersAreSkipped() {
        setUp(4, range(10, 14), Set.of(11L), Set.of(12L));

        AttendeePreview p = svc.preview(viewer, 5L);

        assertEquals(List.of(10L, 13L), p.avatars().stream().map(a -> a.userId()).toList());
    }

    @Test
    void atMostEightAvatars() {
        setUp(20, range(10, 30), Set.of(), Set.of());

        AttendeePreview p = svc.preview(viewer, 5L);

        assertEquals(8, p.avatars().size());
        assertEquals(20, p.goingCount());
    }

    @Test
    void emptyEventHasNoAvatars() {
        setUp(0, Set.of(), Set.of(), Set.of());

        assertTrue(svc.preview(viewer, 5L).avatars().isEmpty());
    }
}
