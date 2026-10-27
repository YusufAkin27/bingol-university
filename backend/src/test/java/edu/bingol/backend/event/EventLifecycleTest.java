package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.notification.NotificationService;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** Etkinlik kapatma/yeniden acma, kapali kayitta RSVP, kulup silinince iptal ve "Etkinliklerim" modlari. */
class EventLifecycleTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final EventService svc = new EventService(events, rsvps, mock(OfficialEventRepository.class), communities,
            notifications, mock(MediaService.class));

    private final Actor organizer = new Actor(99L, false);
    private final Actor stranger = new Actor(1L, false);
    private final Instant start = Instant.now().plus(Duration.ofDays(2));

    private UserEvent event(boolean closed) {
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setTitle("Konferans");
        e.setStartsAt(start);
        e.setEndsAt(start.plus(Duration.ofHours(2)));
        e.setCreatedBy(99L);
        e.setStatus(UserEvent.Status.ACTIVE);
        e.setRegistrationClosed(closed);
        when(events.findById(5L)).thenReturn(Optional.of(e));
        when(communities.namesById(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());
        return e;
    }

    @Test
    void organizerClosesAndReopensRegistration() {
        UserEvent e = event(false);

        EventView closed = svc.setRegistrationClosed(organizer, 5L, true);
        assertTrue(closed.registrationClosed());
        assertTrue(e.isRegistrationClosed());

        EventView reopened = svc.setRegistrationClosed(organizer, 5L, false);
        assertFalse(reopened.registrationClosed());
    }

    @Test
    void strangerCannotCloseRegistration() {
        UserEvent e = event(false);

        ApiException ex = assertThrows(ApiException.class, () -> svc.setRegistrationClosed(stranger, 5L, true));

        assertEquals(HttpStatus.FORBIDDEN, ex.status());
        assertFalse(e.isRegistrationClosed());
    }

    @Test
    void cannotCloseCancelledEvent() {
        UserEvent e = event(false);
        e.setStatus(UserEvent.Status.CANCELLED);

        ApiException ex = assertThrows(ApiException.class, () -> svc.setRegistrationClosed(organizer, 5L, true));

        assertEquals("EVENT_NOT_EDITABLE", ex.code());
    }

    @Test
    void newRsvpIsRejectedWhenRegistrationClosed() {
        event(true);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());

        ApiException ex = assertThrows(ApiException.class, () -> svc.rsvp(stranger, 5L, EventRsvp.Status.GOING));

        assertEquals(HttpStatus.CONFLICT, ex.status());
        assertEquals("EVENT_REGISTRATION_CLOSED", ex.code());
        verify(rsvps, never()).saveAndFlush(any());
    }

    @Test
    void interestedUserCannotUpgradeToGoingWhenClosed() {
        event(true);
        when(rsvps.findByEventIdAndUserId(5L, 1L))
                .thenReturn(Optional.of(new EventRsvp(5L, 1L, EventRsvp.Status.INTERESTED)));

        ApiException ex = assertThrows(ApiException.class, () -> svc.rsvp(stranger, 5L, EventRsvp.Status.GOING));

        assertEquals("EVENT_REGISTRATION_CLOSED", ex.code());
    }

    @Test
    void existingGoingRsvpUnaffectedByCloseAndCanWithdraw() {
        event(true);
        EventRsvp going = new EventRsvp(5L, 1L, EventRsvp.Status.GOING);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(going));
        when(events.goingCount(5L)).thenReturn(1);

        // ayni durumu yinelemek hata vermez
        assertEquals(EventRsvp.Status.GOING, svc.rsvp(stranger, 5L, EventRsvp.Status.GOING).myRsvp());

        // geri cekilme (RSVP silme) kapali kayitta da calisir
        svc.cancelRsvp(stranger, 5L);
        verify(rsvps).delete(going);
    }

    @Test
    void openRegistrationStillAcceptsRsvp() {
        event(false);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        when(events.tryIncrementGoing(5L)).thenReturn(1);
        when(events.goingCount(5L)).thenReturn(1);

        assertEquals(EventRsvp.Status.GOING, svc.rsvp(stranger, 5L, EventRsvp.Status.GOING).myRsvp());
    }

    @Test
    void clubDeletionCancelsLiveEventsAndNotifiesGoing() {
        UserEvent e = event(false);
        e.setCommunityId(10L);
        when(events.liveIdsByCommunity(eq(10L), any(), any())).thenReturn(List.of(5L));
        when(rsvps.userIds(eq(5L), eq(EventRsvp.Status.GOING), any())).thenReturn(List.of(1L, 2L));

        int n = svc.cancelForDeletedClub(10L);

        assertEquals(1, n);
        assertEquals(UserEvent.Status.CANCELLED, e.getStatus());
        verify(notifications).sendTemplated(eq(1L), any(), eq("notif.event.cancelled"), any(), anyString());
        verify(notifications).sendTemplated(eq(2L), any(), eq("notif.event.cancelled"), any(), anyString());
    }

    @Test
    void myEventsModesUseMatchingQueries() {
        when(events.mineUpcoming(any(), any(), any(), anyLong(), eq(1L), eq(true), eq(false), any(), any(), any(), any(), any()))
                .thenReturn(List.of());
        when(events.mineUpcoming(any(), any(), any(), anyLong(), eq(1L), eq(false), eq(true), any(), any(), any(), any(), any()))
                .thenReturn(List.of());
        when(events.minePast(any(), any(), any(), anyLong(), eq(1L), any(), any(), any(), any())).thenReturn(List.of());

        svc.mine(stranger, "upcoming", null, 20);
        svc.mine(stranger, "going", null, 20);
        svc.mine(stranger, "past", null, 20);
        svc.mine(stranger, "created", null, 20);

        verify(events).mineUpcoming(any(), any(), any(), anyLong(), eq(1L), eq(true), eq(false), any(), any(), any(), any(), any());
        verify(events).mineUpcoming(any(), any(), any(), anyLong(), eq(1L), eq(false), eq(true), any(), any(), any(), any(), any());
        verify(events).minePast(any(), any(), any(), anyLong(), eq(1L), any(), any(), any(), any());
        verify(events).organizing(eq(1L), any(), anyLong(), any());
    }
}
