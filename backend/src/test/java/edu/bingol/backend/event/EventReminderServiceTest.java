package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

class EventReminderServiceTest {

    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final EventReminderService svc = new EventReminderService(rsvps, notifications);
    private final Instant now = Instant.parse("2026-11-01T10:00:00Z");

    private Object[] row(long rsvpId, long userId) {
        EventRsvp r = new EventRsvp(5L, userId, EventRsvp.Status.GOING);
        r.setId(rsvpId);
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setTitle("Konferans");
        return new Object[] {r, e};
    }

    @Test
    void sendsHourReminderOnceWhenClaimed() {
        when(rsvps.hourCandidates(any(), any(), any(), any(), any())).thenReturn(List.<Object[]>of(row(1L, 11L)));
        when(rsvps.dayCandidates(any(), any(), any(), any(), any())).thenReturn(List.of());
        when(rsvps.claimHour(1L)).thenReturn(1);

        assertEquals(1, svc.run(now));

        verify(notifications).sendTemplated(eq(11L), eq(NotificationType.EVENT), eq("notif.event.reminderHour"), any(), any(String[].class));
    }

    @Test
    void alreadyClaimedReminderIsNotSentAgain() {
        when(rsvps.hourCandidates(any(), any(), any(), any(), any())).thenReturn(List.<Object[]>of(row(1L, 11L)));
        when(rsvps.dayCandidates(any(), any(), any(), any(), any())).thenReturn(List.<Object[]>of(row(2L, 12L)));
        when(rsvps.claimHour(1L)).thenReturn(0);
        when(rsvps.claimDay(2L)).thenReturn(0);

        assertEquals(0, svc.run(now));

        verify(notifications, never()).send(any(), any(), any(), any(), any());
    }

    @Test
    void sendsDayReminderWhenClaimed() {
        when(rsvps.hourCandidates(any(), any(), any(), any(), any())).thenReturn(List.of());
        when(rsvps.dayCandidates(any(), any(), any(), any(), any())).thenReturn(List.<Object[]>of(row(2L, 12L)));
        when(rsvps.claimDay(2L)).thenReturn(1);

        assertEquals(1, svc.run(now));

        verify(notifications).sendTemplated(eq(12L), eq(NotificationType.EVENT), eq("notif.event.reminderDay"), any(), any(String[].class));
    }
}
