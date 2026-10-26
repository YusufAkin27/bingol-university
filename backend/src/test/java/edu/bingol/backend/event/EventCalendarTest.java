package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.CursorPage;
import edu.bingol.backend.common.storage.FileStorage;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.event.EventService.CalendarResult;
import edu.bingol.backend.event.dto.EventDtos.CalendarItem;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import edu.bingol.backend.event.extras.CoOrganizerLookup;
import edu.bingol.backend.news.NewsItem;
import edu.bingol.backend.notification.NotificationService;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** Takvim birlesimi, ay siniri, truncated bayragi ve liste goruntulerinde toplu hesap. */
class EventCalendarTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final OfficialEventRepository official = mock(OfficialEventRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final EventService svc = new EventService(events, rsvps, official, communities,
            mock(NotificationService.class), mock(FileStorage.class));

    private final Actor me = new Actor(1L, false);
    private final YearMonth november = YearMonth.of(2026, 11);

    private UserEvent event(long id, Instant start, Instant end, Long communityId) {
        UserEvent e = new UserEvent();
        e.setId(id);
        e.setTitle("Etkinlik " + id);
        e.setStartsAt(start);
        e.setEndsAt(end);
        e.setCreatedBy(99L);
        e.setCommunityId(communityId);
        e.setGoingCount(3);
        e.setCapacity(10);
        e.setStatus(UserEvent.Status.ACTIVE);
        return e;
    }

    private void upcoming(List<UserEvent> rows) {
        when(events.upcoming(any(), any(), any(), anyLong(), any(), anyLong(), any(), any(), any(), any(), any()))
                .thenReturn(rows);
    }

    @Test
    void multiDayEventFromPreviousMonthIsClampedToFirstDay() {
        // 28 Ekim 12:00 -> 3 Kasim; Kasim takviminde 1 Kasim gorunur
        upcoming(List.of(event(7L, Instant.parse("2026-10-28T09:00:00Z"), Instant.parse("2026-11-03T09:00:00Z"), null)));
        when(official.inRange(any(), any(), any(), any())).thenReturn(List.of());

        List<CalendarItem> items = svc.calendar(me, november);

        assertEquals(LocalDate.of(2026, 11, 1), items.get(0).date());
        assertEquals(Instant.parse("2026-10-28T09:00:00Z"), items.get(0).startsAt());
    }

    @Test
    void userItemsCarryRsvpCountsCapacityStatusAndCommunityName() {
        upcoming(List.of(event(7L, Instant.parse("2026-11-10T09:00:00Z"), Instant.parse("2026-11-10T11:00:00Z"), 4L)));
        when(official.inRange(any(), any(), any(), any())).thenReturn(List.of());
        when(rsvps.findByUserIdAndEventIdIn(eq(1L), anyCollection()))
                .thenReturn(List.of(new EventRsvp(7L, 1L, EventRsvp.Status.INTERESTED)));
        when(rsvps.countByEvents(anyCollection(), eq(EventRsvp.Status.INTERESTED)))
                .thenReturn(Collections.singletonList(new Object[] {7L, 5L}));
        when(communities.namesById(anyCollection())).thenReturn(Map.of(4L, "Kulup"));

        CalendarItem item = svc.calendar(me, november).get(0);

        assertEquals("USER", item.source());
        assertEquals(EventRsvp.Status.INTERESTED, item.myRsvp());
        assertEquals(3, item.goingCount());
        assertEquals(5L, item.interestedCount());
        assertEquals(10, item.capacity());
        assertEquals(UserEvent.Status.ACTIVE, item.status());
        assertEquals("Kulup", item.communityName());
    }

    @Test
    void officialItemsKeepPublishDateAndHaveNoUserMetadata() {
        upcoming(List.of());
        NewsItem n = new NewsItem();
        n.setId(11L);
        n.setTitle("Resmi etkinlik");
        n.setPublishedDate(LocalDate.of(2026, 11, 5));
        when(official.inRange(any(), any(), any(), any())).thenReturn(List.of(n));

        CalendarItem item = svc.calendar(me, november).get(0);

        assertEquals("OFFICIAL", item.source());
        assertEquals(LocalDate.of(2026, 11, 5), item.date());
        assertNull(item.myRsvp());
        assertNull(item.goingCount());
        assertNull(item.status());
    }

    @Test
    void metadataIsFetchedInBulkNotPerItem() {
        List<UserEvent> rows = new ArrayList<>();
        for (long i = 1; i <= 20; i++) {
            rows.add(event(i, Instant.parse("2026-11-10T09:00:00Z"), Instant.parse("2026-11-10T11:00:00Z"), null));
        }
        upcoming(rows);
        when(official.inRange(any(), any(), any(), any())).thenReturn(List.of());

        svc.calendar(me, november);

        verify(rsvps, times(1)).findByUserIdAndEventIdIn(eq(1L), anyCollection());
        verify(rsvps, times(1)).countByEvents(anyCollection(), eq(EventRsvp.Status.INTERESTED));
    }

    @Test
    void truncatedWhenUserLimitIsHit() {
        List<UserEvent> rows = new ArrayList<>();
        for (long i = 1; i <= EventService.CALENDAR_USER_LIMIT + 1; i++) {
            rows.add(event(i, Instant.parse("2026-11-10T09:00:00Z"), Instant.parse("2026-11-10T11:00:00Z"), null));
        }
        upcoming(rows);
        when(official.inRange(any(), any(), any(), any())).thenReturn(List.of());

        CalendarResult r = svc.calendarResult(me, november);

        assertTrue(r.truncated());
        assertEquals(EventService.CALENDAR_USER_LIMIT, r.items().size());
    }

    @Test
    void notTruncatedWhenWithinLimits() {
        upcoming(List.of());
        when(official.inRange(any(), any(), any(), any())).thenReturn(List.of());

        assertFalse(svc.calendarResult(me, november).truncated());
    }

    @Test
    void canManageIsComputedInBulkForListViews() {
        Instant s = Instant.parse("2026-11-10T09:00:00Z");
        UserEvent a = event(1L, s, s.plusSeconds(3600), 4L);
        UserEvent b = event(2L, s, s.plusSeconds(3600), 4L);
        UserEvent c = event(3L, s, s.plusSeconds(3600), null);
        upcoming(List.of(a, b, c));
        when(communities.can(me, 4L, ClubPermission.MANAGE_EVENTS)).thenReturn(true);
        CoOrganizerLookup lookup = mock(CoOrganizerLookup.class);
        when(lookup.coOrganizedAmong(anyCollection(), eq(1L))).thenReturn(Set.of(3L));
        svc.setCoOrganizers(lookup);

        CursorPage<EventView> page = svc.list(me, Instant.parse("2026-11-01T00:00:00Z"), null, null, null, 20);

        assertTrue(page.items().stream().allMatch(EventView::canManage));
        verify(communities, times(1)).can(any(), eq(4L), any());
        verify(lookup, times(1)).coOrganizedAmong(anyCollection(), eq(1L));
    }

    @Test
    void deletedCursorYieldsEmptyPageInsteadOfRestart() {
        when(events.findById(404L)).thenReturn(java.util.Optional.empty());
        upcoming(List.of());

        CursorPage<EventView> page = svc.list(me, null, null, null, 404L, 20);

        assertTrue(page.items().isEmpty());
        ArgumentCaptor<Instant> cs = ArgumentCaptor.forClass(Instant.class);
        verify(events).upcoming(any(), any(), any(), anyLong(), cs.capture(), anyLong(), any(), any(), any(), any(), any());
        assertEquals(EventService.FAR_FUTURE, cs.getValue());
    }
}
