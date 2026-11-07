package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.chat.EventChatHooks;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.notification.NotificationService;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * FIX-P05 (A05#2, A05#4): RSVP durum gecisi kosullu UPDATE ile sahiplenilir; kaybeden istek going_count'a dokunmaz.
 * Sohbet odasi senkronu commit SONRASINDA calisir (etkinlik satir kilidi tutulurken degil).
 */
class RsvpDoubleToggleCounterTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final EventService svc = new EventService(events, rsvps, mock(OfficialEventRepository.class),
            mock(CommunityService.class), mock(NotificationService.class), mock(MediaService.class));
    private final Actor user = new Actor(1L, false);

    @AfterEach
    void cleanSync() {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    private void event() {
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setTitle("Konferans");
        e.setStartsAt(Instant.now().plus(Duration.ofDays(2)));
        e.setEndsAt(Instant.now().plus(Duration.ofDays(2)).plus(Duration.ofHours(2)));
        e.setGoingCount(2);
        e.setCreatedBy(99L);
        e.setStatus(UserEvent.Status.ACTIVE);
        when(events.findById(5L)).thenReturn(Optional.of(e));
    }

    private EventRsvp row(EventRsvp.Status st) {
        EventRsvp r = new EventRsvp(5L, 1L, st);
        r.setId(77L);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(r));
        return r;
    }

    @Test
    void secondGoingToInterestedRequestDoesNotDecrementAgain() {
        event();
        row(EventRsvp.Status.GOING);
        // ilk istek gecisi kazandi (1), ikinci es zamanli istek kaybetti (0)
        when(rsvps.transition(77L, EventRsvp.Status.GOING, EventRsvp.Status.INTERESTED)).thenReturn(1, 0);

        svc.rsvp(user, 5L, EventRsvp.Status.INTERESTED);
        svc.rsvp(user, 5L, EventRsvp.Status.INTERESTED);

        verify(events, org.mockito.Mockito.times(1)).decrementGoing(5L);
    }

    @Test
    void secondInterestedToGoingRequestDoesNotReserveASecondSeat() {
        event();
        row(EventRsvp.Status.INTERESTED);
        when(rsvps.transition(77L, EventRsvp.Status.INTERESTED, EventRsvp.Status.GOING)).thenReturn(1, 0);
        when(events.tryIncrementGoing(5L)).thenReturn(1);

        svc.rsvp(user, 5L, EventRsvp.Status.GOING);
        svc.rsvp(user, 5L, EventRsvp.Status.GOING);

        verify(events, org.mockito.Mockito.times(1)).tryIncrementGoing(5L);
    }

    @Test
    void cancelRsvpDecrementsOnlyForTheRequestThatDeletedTheRow() {
        event();
        EventRsvp r = row(EventRsvp.Status.GOING);
        when(rsvps.deleteClaim(77L)).thenReturn(1, 0);

        svc.cancelRsvp(user, 5L);
        svc.cancelRsvp(user, 5L);

        verify(events, org.mockito.Mockito.times(1)).decrementGoing(5L);
        assertEquals(EventRsvp.Status.GOING, r.getStatus());
    }

    @Test
    void chatRoomSyncRunsOnlyAfterCommit() {
        event();
        row(EventRsvp.Status.INTERESTED);
        when(rsvps.transition(77L, EventRsvp.Status.INTERESTED, EventRsvp.Status.GOING)).thenReturn(1);
        when(events.tryIncrementGoing(5L)).thenReturn(1);
        EventChatHooks chat = mock(EventChatHooks.class);
        svc.setChat(chat);

        TransactionSynchronizationManager.initSynchronization();
        svc.rsvp(user, 5L, EventRsvp.Status.GOING);

        // islem acikken (etkinlik satir kilidi tutuluyor) oda senkronu CALISMAZ
        verify(chat, never()).onGoing(anyLong(), anyLong());
        assertFalse(TransactionSynchronizationManager.getSynchronizations().isEmpty());

        for (TransactionSynchronization s : TransactionSynchronizationManager.getSynchronizations()) {
            s.afterCommit();
        }
        verify(chat).onGoing(eq(5L), eq(1L));
        assertTrue(true);
        verify(rsvps, never()).save(any());
    }
}
