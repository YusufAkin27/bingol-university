package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.dto.EventDtos.CalendarItem;
import edu.bingol.backend.event.dto.EventDtos.UpdateEventRequest;
import edu.bingol.backend.notification.NotificationService;
import java.time.Duration;
import java.time.Instant;
import java.time.YearMonth;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

/** T3 denetim bulgulari icin regresyon testleri (etkinlik modulu). */
class EventQaTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final OfficialEventRepository official = mock(OfficialEventRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final EventService svc = new EventService(events, rsvps, official, communities, notifications,
            mock(FileStorage.class));

    private final Actor stranger = new Actor(1L, false);
    private final Actor owner = new Actor(99L, false);
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

    private static ApiException error(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    // ---- IDOR: gorunmeyen etkinligin varligi sizmaz ----

    @Test
    void strangerGets404NotForbiddenForPendingEvent() {
        UserEvent e = event(UserEvent.Status.PENDING_REVIEW);

        assertEquals(HttpStatus.NOT_FOUND, error(() -> svc.requireManager(stranger, e)).status());
        assertEquals(HttpStatus.NOT_FOUND, error(() -> svc.attendees(stranger, 5L, null, null, 10)).status());
        assertEquals(HttpStatus.NOT_FOUND,
                error(() -> svc.update(stranger, 5L, new UpdateEventRequest("Yeni", null, null, null, null, null))).status());
        assertEquals(HttpStatus.NOT_FOUND, error(() -> svc.delete(stranger, 5L)).status());
    }

    @Test
    void strangerGets404ForCancelledAndPrivateCommunityEvents() {
        UserEvent cancelled = event(UserEvent.Status.CANCELLED);
        assertEquals(HttpStatus.NOT_FOUND, error(() -> svc.requireManager(stranger, cancelled)).status());

        UserEvent priv = event(UserEvent.Status.ACTIVE);
        priv.setCommunityId(10L);
        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        c.setVisibility(Community.Visibility.PRIVATE);
        when(communities.load(10L)).thenReturn(c);
        when(communities.roleOf(10L, 1L)).thenReturn(Optional.empty());
        assertEquals(HttpStatus.NOT_FOUND, error(() -> svc.requireManager(stranger, priv)).status());
    }

    @Test
    void strangerStillGets403ForVisibleEvent() {
        UserEvent e = event(UserEvent.Status.ACTIVE);

        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.requireManager(stranger, e)).status());
        assertEquals(e, svc.requireManager(owner, e));
    }

    // ---- tarih sinirlari ----

    @Test
    void farFutureDatesAreRejected() {
        Instant far = Instant.parse("2100-06-01T00:00:00Z");
        assertEquals("INVALID_DATES",
                error(() -> svc.create(stranger, new edu.bingol.backend.event.dto.EventDtos.CreateEventRequest(
                        "Uzak", null, far, far.plusSeconds(60), null, null, null))).code());
        assertEquals("INVALID_DATES", error(() -> EventService.validateDates(start, Instant.MAX)).code());
    }

    @Test
    void updateCannotMoveEventBeyondFarFuture() {
        UserEvent e = event(UserEvent.Status.ACTIVE);
        e.setCreatedBy(1L);
        Instant far = Instant.parse("2200-01-01T00:00:00Z");

        assertEquals("INVALID_DATES",
                error(() -> svc.update(stranger, 5L, new UpdateEventRequest(null, null, far, far.plusSeconds(60), null, null))).code());
    }

    @Test
    void listClampsExtremeRange() {
        when(events.upcoming(any(), any(), any(), anyLong(), any(), anyLong(), any(), any(), any(), any(), any()))
                .thenReturn(List.of());

        svc.list(stranger, Instant.MIN, Instant.MAX, null, null, 20);

        ArgumentCaptor<Instant> from = ArgumentCaptor.forClass(Instant.class);
        ArgumentCaptor<Instant> to = ArgumentCaptor.forClass(Instant.class);
        verify(events).upcoming(any(), from.capture(), to.capture(), anyLong(), any(), anyLong(), any(), any(), any(),
                any(), any());
        assertEquals(EventService.MIN_DATE, from.getValue());
        assertEquals(EventService.FAR_FUTURE, to.getValue());
    }

    @Test
    void listPageSizeIsClamped() {
        when(events.upcoming(any(), any(), any(), anyLong(), any(), anyLong(), any(), any(), any(), any(), any()))
                .thenReturn(List.of());

        svc.list(stranger, null, null, null, null, 100000);
        svc.list(stranger, null, null, null, null, -5);

        ArgumentCaptor<org.springframework.data.domain.Pageable> p =
                ArgumentCaptor.forClass(org.springframework.data.domain.Pageable.class);
        verify(events, times(2)).upcoming(any(), any(), any(), anyLong(), any(), anyLong(), any(), any(), any(), any(),
                p.capture());
        assertEquals(51, p.getAllValues().get(0).getPageSize()); // 50 + 1 (sonraki sayfa var mi)
        assertEquals(2, p.getAllValues().get(1).getPageSize());
    }

    // ---- takvim: saat dilimi / ay siniri ----

    @Test
    void calendarMonthBoundsUseIstanbulMidnight() {
        when(events.upcoming(any(), any(), any(), anyLong(), any(), anyLong(), any(), any(), any(), any(), any()))
                .thenReturn(List.of());
        when(official.inRange(any(), any(), any(), any())).thenReturn(List.of());

        svc.calendar(stranger, YearMonth.of(2026, 11));

        ArgumentCaptor<Instant> from = ArgumentCaptor.forClass(Instant.class);
        ArgumentCaptor<Instant> to = ArgumentCaptor.forClass(Instant.class);
        verify(events).upcoming(any(), from.capture(), to.capture(), anyLong(), any(), anyLong(), any(), any(), any(),
                any(), any());
        // Turkiye UTC+3 sabit: 1 Kasim 00:00 yerel = 31 Ekim 21:00Z
        assertEquals(Instant.parse("2026-10-31T21:00:00Z"), from.getValue());
        assertEquals(Instant.parse("2026-11-30T21:00:00Z"), to.getValue());
    }

    @Test
    void calendarDateIsLocalDayAcrossMonthBoundary() {
        UserEvent e = new UserEvent();
        e.setId(7L);
        e.setTitle("Gece yarisi");
        e.setStartsAt(Instant.parse("2026-10-31T21:30:00Z")); // yerel 1 Kasim 00:30
        e.setEndsAt(Instant.parse("2026-10-31T23:30:00Z"));
        when(events.upcoming(any(), any(), any(), anyLong(), any(), anyLong(), any(), any(), any(), any(), any()))
                .thenReturn(List.of(e));
        when(official.inRange(any(), any(), any(), any())).thenReturn(List.of());

        List<CalendarItem> items = svc.calendar(stranger, YearMonth.of(2026, 11));

        assertEquals(java.time.LocalDate.of(2026, 11, 1), items.get(0).date());
    }

    @Test
    void calendarRejectsAbsurdMonths() {
        assertEquals("INVALID_DATES", error(() -> svc.calendar(stranger, YearMonth.of(1900, 1))).code());
        assertEquals("INVALID_DATES", error(() -> svc.calendar(stranger, YearMonth.of(999999, 1))).code());
    }

    // ---- hatirlatma bayraklari ----

    @Test
    void rescheduleResetsReminderFlags() {
        UserEvent e = event(UserEvent.Status.ACTIVE);
        e.setCreatedBy(1L);
        when(communities.usersById(any())).thenReturn(Map.of());
        when(communities.namesById(any())).thenReturn(Map.of());

        svc.update(stranger, 5L, new UpdateEventRequest(null, null, start.plusSeconds(3600), end.plusSeconds(3600), null, null));

        verify(rsvps).resetReminders(5L);
    }

    @Test
    void nonScheduleUpdateKeepsReminderFlags() {
        UserEvent e = event(UserEvent.Status.ACTIVE);
        e.setCreatedBy(1L);
        when(communities.usersById(any())).thenReturn(Map.of());
        when(communities.namesById(any())).thenReturn(Map.of());

        svc.update(stranger, 5L, new UpdateEventRequest(null, "yeni aciklama", null, null, null, null));

        verify(rsvps, never()).resetReminders(anyLong());
    }

    @Test
    void togglingRsvpDoesNotReArmReminders() {
        UserEvent e = event(UserEvent.Status.ACTIVE);
        e.setGoingCount(1);
        EventRsvp r = new EventRsvp(5L, 1L, EventRsvp.Status.GOING);
        r.setRemindedDay(true);
        r.setRemindedHour(true);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(r));
        when(events.tryIncrementGoing(5L)).thenReturn(1);

        svc.rsvp(stranger, 5L, EventRsvp.Status.INTERESTED);
        svc.rsvp(stranger, 5L, EventRsvp.Status.GOING);

        assertTrue(r.isRemindedDay());
        assertTrue(r.isRemindedHour());
    }

    // ---- iptal bildirimi ----

    @Test
    void cancellingEndedEventDoesNotNotify() {
        UserEvent e = event(UserEvent.Status.ACTIVE);
        e.setCreatedBy(1L);
        e.setStartsAt(Instant.now().minus(Duration.ofHours(5)));
        e.setEndsAt(Instant.now().minus(Duration.ofHours(3)));
        when(rsvps.userIds(eq(5L), any(), any())).thenReturn(List.of(50L));

        svc.delete(stranger, 5L);

        assertEquals(UserEvent.Status.CANCELLED, e.getStatus());
        verify(notifications, never()).sendTemplated(any(), any(), any(), any(), any(String[].class));
    }

    @Test
    void cancellingUpcomingEventNotifiesGoingExceptOrganizer() {
        UserEvent e = event(UserEvent.Status.ACTIVE);
        e.setCreatedBy(1L);
        when(rsvps.userIds(eq(5L), any(), any())).thenReturn(List.of(1L, 50L, 51L));

        svc.delete(stranger, 5L);

        verify(notifications, times(2)).sendTemplated(any(), any(), eq("notif.event.cancelled"), any(), any(String[].class));
        verify(notifications, never()).sendTemplated(eq(1L), any(), any(), any(), any(String[].class));
    }

    @Test
    void cancelIsIdempotent() {
        UserEvent e = event(UserEvent.Status.CANCELLED);
        e.setCreatedBy(1L);

        svc.delete(stranger, 5L);

        verify(events, never()).save(any());
    }

    // ---- RSVP kenar durumlari ----

    @Test
    void cannotRsvpToCancelledEvent() {
        UserEvent e = event(UserEvent.Status.CANCELLED);
        e.setCreatedBy(1L);

        assertEquals("EVENT_NOT_OPEN", error(() -> svc.rsvp(stranger, 5L, EventRsvp.Status.GOING)).code());
    }

    @Test
    void cancelRsvpOfInterestedDoesNotTouchCounter() {
        event(UserEvent.Status.ACTIVE);
        when(rsvps.findByEventIdAndUserId(5L, 1L))
                .thenReturn(Optional.of(new EventRsvp(5L, 1L, EventRsvp.Status.INTERESTED)));

        svc.cancelRsvp(stranger, 5L);

        verify(events, never()).decrementGoing(anyLong());
    }

    @Test
    void capacityZeroMakesEventUnlimited() {
        UserEvent e = event(UserEvent.Status.ACTIVE);
        e.setCreatedBy(1L);
        e.setCapacity(5);
        e.setGoingCount(5);
        when(communities.usersById(any())).thenReturn(Map.of());
        when(communities.namesById(any())).thenReturn(Map.of());

        svc.update(stranger, 5L, new UpdateEventRequest(null, null, null, null, null, 0));

        assertEquals(null, e.getCapacity());
    }

    @Test
    void startedEventStartCannotBeMoved() {
        UserEvent e = event(UserEvent.Status.ACTIVE);
        e.setCreatedBy(1L);
        e.setStartsAt(Instant.now().minus(Duration.ofMinutes(10)));

        ApiException ex = error(() -> svc.update(stranger, 5L,
                new UpdateEventRequest(null, null, Instant.now().plus(Duration.ofDays(1)), end, null, null)));

        assertEquals("EVENT_STARTED", ex.code());
        assertFalse(ex.status().is2xxSuccessful());
    }
}
