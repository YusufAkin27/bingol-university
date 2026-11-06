package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.admission.EventAdmissionHooks;
import edu.bingol.backend.event.dto.EventDtos.CreateEventRequest;
import edu.bingol.backend.event.extras.EventSeriesMemberRepository;
import edu.bingol.backend.event.extras.SeriesService;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.notification.NotificationService;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/**
 * FIX-P05 (A05#6, K14): "acik etkinlik" / "gunluk acma" sinirlari (EventAdmissionHooks.beforeCreate) eskiden hic
 * cagrilmiyordu. Artik etkinlik olusturmada ve tekrar serisinde (kopya sayisi kadar) uygulanir.
 */
class EventCreateLimitWiringTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final EventService svc = new EventService(events, mock(EventRsvpRepository.class),
            mock(OfficialEventRepository.class), communities, mock(NotificationService.class), mock(MediaService.class));
    private final Actor user = new Actor(1L, false);
    private final Instant start = Instant.now().plus(Duration.ofDays(2));

    private CreateEventRequest req() {
        return new CreateEventRequest("Konferans", "aciklama", start, start.plus(Duration.ofHours(2)), "Salon", 50, 10L, null);
    }

    @Test
    void createAppliesTheOpenAndDailyLimitsAndStopsBeforeSaving() {
        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(c);
        when(communities.roleOf(10L, 1L)).thenReturn(java.util.Optional.of(edu.bingol.backend.community.CommunityMember.Role.OWNER));
        EventAdmissionHooks hooks = mock(EventAdmissionHooks.class);
        svc.setAdmission(hooks);
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "EVENT_LIMIT_DAILY", "x", "5")).when(hooks).beforeCreate(user);

        ApiException ex = assertThrows(ApiException.class, () -> svc.create(user, req()));

        assertEquals("EVENT_LIMIT_DAILY", ex.code());
        verify(hooks).beforeCreate(user);
        verify(events, never()).save(any());
    }

    @Test
    void seriesCountsEveryCopyAgainstTheLimits() {
        EventService eventSvc = mock(EventService.class);
        UserEventRepository repo = mock(UserEventRepository.class);
        EventSeriesMemberRepository members = mock(EventSeriesMemberRepository.class);
        UserEvent src = new UserEvent();
        src.setId(10L);
        src.setTitle("Seri");
        src.setCreatedBy(1L);
        src.setStatus(UserEvent.Status.ACTIVE);
        src.setStartsAt(start);
        src.setEndsAt(start.plusSeconds(3600));
        when(eventSvc.load(10L)).thenReturn(src);
        when(eventSvc.requireManager(user, src)).thenReturn(src);
        when(members.findByEventId(10L)).thenReturn(Optional.empty());
        EventAdmissionHooks hooks = mock(EventAdmissionHooks.class);
        doThrow(new ApiException(HttpStatus.CONFLICT, "EVENT_LIMIT_OPEN", "x", "5")).when(hooks).beforeCreate(eq(user), eq(6));
        SeriesService series = new SeriesService(eventSvc, repo, members);
        series.setAdmission(hooks);

        ApiException ex = assertThrows(ApiException.class, () -> series.create(user, 10L, 6, Instant.now()));

        assertEquals("EVENT_LIMIT_OPEN", ex.code());
        verify(repo, never()).save(any());
    }
}
