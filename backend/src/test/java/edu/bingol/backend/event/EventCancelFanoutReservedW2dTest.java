package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.dto.EventDtos.CreateEventRequest;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;

/** T-049 (iptal sonrasi salt okunur erisim + neden), T-051 (500 sinirsiz bildirim), T-052 (kurum taklidi basligi). */
class EventCancelFanoutReservedW2dTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final EventService svc = new EventService(events, rsvps, mock(OfficialEventRepository.class), communities,
            notifications, mock(MediaService.class));

    private final Instant start = Instant.now().plus(Duration.ofDays(2));
    private final Instant end = start.plus(Duration.ofHours(2));

    private UserEvent event(UserEvent.Status status) {
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setTitle("Konferans");
        e.setStartsAt(start);
        e.setEndsAt(end);
        e.setCreatedBy(99L);
        e.setStatus(status);
        when(events.findById(5L)).thenReturn(Optional.of(e));
        return e;
    }

    private void rsvp(long userId, EventRsvp.Status st) {
        EventRsvp r = new EventRsvp(5L, userId, st);
        when(rsvps.findByEventIdAndUserId(5L, userId)).thenReturn(Optional.of(r));
        when(rsvps.findByUserIdAndEventIdIn(eq(userId), any())).thenReturn(List.of(r));
    }

    // ---- T-049 ----

    @Test
    void attendeeStillReadsCancelledEventWithOrganizerReason() {
        UserEvent e = event(UserEvent.Status.CANCELLED);
        e.setCancelReason("Hava kosullari");
        e.setModerationReason("ic not: sikayet");
        rsvp(1L, EventRsvp.Status.GOING);

        EventView v = svc.get(new Actor(1L, false), 5L);

        assertEquals(UserEvent.Status.CANCELLED, v.status());
        assertEquals("Hava kosullari", v.cancelReason()); // yonetici ic notu katilimciya sizmaz
        assertEquals(EventRsvp.Status.GOING, v.myRsvp());
    }

    @Test
    void strangerStillGets404ForCancelledEvent() {
        event(UserEvent.Status.CANCELLED);

        ApiException ex = assertThrows(ApiException.class, () -> svc.get(new Actor(2L, false), 5L));

        assertEquals("EVENT_NOT_FOUND", ex.code());
    }

    @Test
    void cancelReasonIsHiddenFromNonParticipantsAndStoredOnOrganizerCancel() {
        UserEvent e = event(UserEvent.Status.ACTIVE);

        svc.delete(new Actor(99L, false), 5L, "  Hava kosullari  ");

        assertEquals(UserEvent.Status.CANCELLED, e.getStatus());
        assertEquals("Hava kosullari", e.getCancelReason());
        assertNull(e.getModerationReason());
    }

    @Test
    void tooLongCancelReasonIsRejected() {
        event(UserEvent.Status.ACTIVE);

        assertEquals("VALIDATION_ERROR",
                assertThrows(ApiException.class, () -> svc.delete(new Actor(99L, false), 5L, "x".repeat(301))).code());
    }

    // ---- T-051 ----

    @Test
    void cancelNotifiesAll600GoingAttendeesNotJustTheFirst500() {
        event(UserEvent.Status.ACTIVE);
        List<Long> first = new ArrayList<>();
        for (long i = 1001; i < 1501; i++) {
            first.add(i);
        }
        List<Long> second = new ArrayList<>();
        for (long i = 1501; i < 1601; i++) {
            second.add(i);
        }
        when(rsvps.userIdsAfter(eq(5L), eq(EventRsvp.Status.GOING), eq(0L), any())).thenReturn(first);
        when(rsvps.userIdsAfter(eq(5L), eq(EventRsvp.Status.GOING), eq(1500L), any())).thenReturn(second);

        svc.delete(new Actor(99L, false), 5L);

        verify(notifications, times(600)).sendTemplated(anyLong(), eq(NotificationType.EVENT),
                eq("notif.event.cancelled"), anyMap(), eq("Konferans"));
    }

    // ---- T-052 ----

    private CreateEventRequest create(String title) {
        return new CreateEventRequest(title, "aciklama", start, end, "Salon", null, 10L, null);
    }

    private void staffInClub() {
        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(c);
        when(communities.roleOf(10L, 1L)).thenReturn(Optional.of(CommunityMember.Role.MODERATOR));
        when(events.save(any())).thenAnswer(i -> {
            UserEvent saved = i.getArgument(0);
            saved.setId(77L);
            return saved;
        });
        when(communities.namesById(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());
    }

    @Test
    void impersonatingTitleGoesToReviewEvenForClubModerator() {
        staffInClub();
        Actor mod = new Actor(1L, false);

        assertEquals(UserEvent.Status.PENDING_REVIEW,
                svc.create(mod, create("Bingöl Üniversitesi Rektörlüğü Duyurusu")).status());
        assertEquals(UserEvent.Status.PENDING_REVIEW, svc.create(mod, create("BU Kampus Resmi Duyuru")).status());
        assertEquals(UserEvent.Status.ACTIVE, svc.create(mod, create("Yazılım Atölyesi")).status());
    }

    @Test
    void bidiOrInvisibleCharactersInTitleAreRejected() {
        staffInClub();

        ApiException ex = assertThrows(ApiException.class,
                () -> svc.create(new Actor(1L, false), create("Konfe‮ransi")));

        assertEquals("INVALID_DISPLAY_NAME", ex.code());
    }
}
