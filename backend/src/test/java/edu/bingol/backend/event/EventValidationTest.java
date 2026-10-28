package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.dto.EventDtos.CreateEventRequest;
import edu.bingol.backend.event.dto.EventDtos.UpdateEventRequest;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.notification.NotificationService;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** Etkinlik yazma dogrulamasi: baslik 100, yer 120, aciklama 1000, bitis > baslangic, en cok 30 gun. */
class EventValidationTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final EventService svc = new EventService(events, mock(EventRsvpRepository.class),
            mock(OfficialEventRepository.class), communities, mock(NotificationService.class), mock(MediaService.class));

    private final Actor admin = new Actor(500L, true);
    private final Instant start = Instant.now().plus(Duration.ofDays(2));
    private final Instant end = start.plus(Duration.ofHours(2));

    private static String chars(int n) {
        return "a".repeat(n);
    }

    private CreateEventRequest req(String title, String desc, String loc, Instant s, Instant e) {
        return new CreateEventRequest(title, desc, s, e, loc, null, 10L, null);
    }

    private ApiException fail(Runnable r) {
        ApiException ex = assertThrows(ApiException.class, r::run);
        assertEquals(HttpStatus.BAD_REQUEST, ex.status());
        return ex;
    }

    private void okClub() {
        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(c);
        when(events.save(any())).thenAnswer(i -> i.getArgument(0));
        when(communities.namesById(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());
    }

    @Test
    void boundaryLengthsAreAccepted() {
        okClub();
        // 100 / 120 / 1000 tam sinir; kenar bosluklari sayilmaz (kirpilir)
        svc.create(admin, req("  " + chars(100) + "  ", chars(1000) + "   ", chars(120), start, end));
        verify(events).save(any());
    }

    @Test
    void tooLongTitleDescriptionAndLocationAreRejected() {
        assertEquals("EVENT_TITLE_TOO_LONG", fail(() -> svc.create(admin, req(chars(101), null, null, start, end))).code());
        assertEquals("EVENT_DESCRIPTION_TOO_LONG",
                fail(() -> svc.create(admin, req("Baslik", chars(1001), null, start, end))).code());
        assertEquals("EVENT_LOCATION_TOO_LONG",
                fail(() -> svc.create(admin, req("Baslik", null, chars(121), start, end))).code());
        verify(events, never()).save(any());
    }

    @Test
    void titleIsTooShortAfterTrimming() {
        assertEquals("VALIDATION_ERROR", fail(() -> svc.create(admin, req("  ab  ", null, null, start, end))).code());
    }

    @Test
    void endMustBeStrictlyAfterStart() {
        assertEquals("INVALID_DATES", fail(() -> svc.create(admin, req("Baslik", null, null, start, start))).code());
        assertEquals("INVALID_DATES",
                fail(() -> svc.create(admin, req("Baslik", null, null, start, start.minusSeconds(1)))).code());
    }

    @Test
    void pastStartIsRejectedAndFutureAccepted() {
        Instant past = Instant.now().minusSeconds(60);
        assertEquals("PAST_EVENT", fail(() -> svc.create(admin, req("Baslik", null, null, past, past.plusSeconds(3600)))).code());
    }

    @Test
    void durationIsCappedAtThirtyDays() {
        okClub();
        svc.create(admin, req("Baslik", null, null, start, start.plus(Duration.ofDays(30)))); // tam 30 gun serbest
        assertEquals("EVENT_TOO_LONG",
                fail(() -> svc.create(admin, req("Baslik", null, null, start, start.plus(Duration.ofDays(30)).plusSeconds(1)))).code());
    }

    // ---- guncelleme (kulup yoneticisi ve admin ayni yolu kullanir) ----

    private UserEvent existing(String desc) {
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setTitle("Konferans");
        e.setDescription(desc);
        e.setStartsAt(start);
        e.setEndsAt(end);
        e.setCreatedBy(99L);
        e.setStatus(UserEvent.Status.ACTIVE);
        when(events.findById(5L)).thenReturn(Optional.of(e));
        return e;
    }

    @Test
    void updateAppliesSameLimits() {
        existing("kisa");
        assertEquals("EVENT_DESCRIPTION_TOO_LONG",
                fail(() -> svc.update(admin, 5L, new UpdateEventRequest(null, chars(1001), null, null, null, null, null))).code());
        assertEquals("EVENT_TITLE_TOO_LONG",
                fail(() -> svc.update(admin, 5L, new UpdateEventRequest(chars(101), null, null, null, null, null, null))).code());
        assertEquals("EVENT_LOCATION_TOO_LONG",
                fail(() -> svc.update(admin, 5L, new UpdateEventRequest(null, null, null, null, chars(121), null, null))).code());
        assertEquals("EVENT_TOO_LONG", fail(() -> svc.update(admin, 5L, new UpdateEventRequest(null, null, null,
                start.plus(Duration.ofDays(31)), null, null, null))).code());
        assertEquals("INVALID_DATES", fail(() -> svc.update(admin, 5L, new UpdateEventRequest(null, null, null,
                start, null, null, null))).code());
        verify(events, never()).save(any());
    }

    @Test
    void updateKeepsLegacyOverlongTextWhenUnchanged() {
        String legacy = chars(1500); // eski kayit sinirdan uzun
        UserEvent e = existing(legacy);
        when(events.save(any())).thenAnswer(i -> i.getArgument(0));
        when(communities.namesById(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());

        // ayni aciklama yeniden gonderilince (yalniz baslik degisiyor) engel yok
        svc.update(admin, 5L, new UpdateEventRequest("Yeni baslik", legacy, null, null, null, null, null));

        assertEquals("Yeni baslik", e.getTitle());
    }
}
