package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.dto.EventDtos.CreateEventRequest;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import edu.bingol.backend.event.dto.EventDtos.UpdateEventRequest;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.notification.NotificationService;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;

/** Bulusma noktasi: olusturma, duzenleme, bitmis etkinlikte yalniz aciklama, bildirim kisma. */
class EventMeetingPointTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final EventService svc = new EventService(events, rsvps, mock(OfficialEventRepository.class), communities,
            mock(NotificationService.class), mock(MediaService.class));
    private final Actor admin = new Actor(500L, true);
    private final Instant start = Instant.now().plus(Duration.ofDays(2));
    private final Instant end = start.plus(Duration.ofHours(2));

    EventMeetingPointTest() {
        when(events.save(any())).thenAnswer(i -> i.getArgument(0));
        when(communities.namesById(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());
    }

    private UserEvent event(Instant s, Instant e) {
        UserEvent ev = new UserEvent();
        ev.setId(5L);
        ev.setTitle("Konferans");
        ev.setStartsAt(s);
        ev.setEndsAt(e);
        ev.setCreatedBy(99L);
        ev.setStatus(UserEvent.Status.ACTIVE);
        ev.setLocation("Salon");
        when(events.findById(5L)).thenReturn(Optional.of(ev));
        return ev;
    }

    private static UpdateEventRequest upd(String point, Double lat, Double lng) {
        return new UpdateEventRequest(null, null, null, null, null, null, null, point, lat, lng);
    }

    @Test
    void createStoresMeetingPointAndCoordinatesSeparateFromLocation() {
        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(c);

        EventView v = svc.create(admin, new CreateEventRequest("Konferans", "a", start, end, "Salon", null, 10L, null,
                "Muhendislik Fakultesi onu", 38.88, 40.5));

        assertEquals("Salon", v.location());
        assertEquals("Muhendislik Fakultesi onu", v.meetingPoint());
        assertEquals(38.88, v.meetingLat());
        assertEquals(40.5, v.meetingLng());
    }

    @Test
    void coordinatesWithoutTextAreDropped() {
        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(c);

        EventView v = svc.create(admin, new CreateEventRequest("Konferans", "a", start, end, "Salon", null, 10L, null,
                "  ", 38.88, 40.5));

        assertNull(v.meetingPoint());
        assertNull(v.meetingLat());
    }

    @Test
    void updateChangesAndClearsMeetingPointAndNotifiesOncePer10Minutes() {
        UserEvent ev = event(start, end);

        EventView v = svc.update(admin, 5L, upd("Ana giris", 38.9, 40.4));
        assertEquals("Ana giris", v.meetingPoint());
        assertEquals(38.9, ev.getMeetingLat());
        Instant first = ev.getUpdateNotifiedAt();
        assertNotNull(first);

        // 10 dk icinde ikinci degisiklik: yeni bildirim damgasi yazilmaz (kisma)
        svc.update(admin, 5L, upd("Yan kapi", null, null));
        assertEquals("Yan kapi", ev.getMeetingPoint());
        assertEquals(first, ev.getUpdateNotifiedAt());

        // bosluk: nokta ve koordinat silinir
        svc.update(admin, 5L, upd(" ", null, null));
        assertNull(ev.getMeetingPoint());
        assertNull(ev.getMeetingLat());
        assertNull(ev.getMeetingLng());
    }

    @Test
    void tooLongMeetingPointIsRejected() {
        event(start, end);
        assertEquals("VALIDATION_ERROR", assertThrows(ApiException.class,
                () -> svc.update(admin, 5L, upd("x".repeat(201), null, null))).code());
    }

    @Test
    void endedEventAllowsOnlyDescription() {
        Instant past = Instant.now().minus(Duration.ofDays(1));
        UserEvent ev = event(past.minus(Duration.ofHours(2)), past);

        assertEquals("EVENT_ENDED", assertThrows(ApiException.class, () -> svc.update(admin, 5L, upd("Kapi", null, null))).code());
        assertEquals("EVENT_ENDED", assertThrows(ApiException.class, () -> svc.update(admin, 5L,
                new UpdateEventRequest("Yeni", null, null, null, null, null, null))).code());
        svc.update(admin, 5L, new UpdateEventRequest(null, "Not eklendi", null, null, null, null, null));
        assertEquals("Not eklendi", ev.getDescription());
    }
}
