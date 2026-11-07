package edu.bingol.backend.notification.live;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.jdbc.core.JdbcTemplate;

/** Canli Etkinlik kaydi: yetki (yalniz kendi sureci), idempotans, sinir, bitirme. Gercek APNs cagrisi YOK. */
class LiveActivityServiceTest {

    static final Instant NOW = Instant.parse("2026-11-07T10:00:00Z");

    LiveActivityRepository repo;
    EventRsvpRepository rsvps;
    UserEventRepository events;
    JdbcTemplate jdbc;
    ApnsLiveActivitySender apns;
    LiveActivityService service;

    @BeforeEach
    void setUp() {
        repo = mock(LiveActivityRepository.class);
        rsvps = mock(EventRsvpRepository.class);
        events = mock(UserEventRepository.class);
        jdbc = mock(JdbcTemplate.class);
        apns = mock(ApnsLiveActivitySender.class);
        service = new LiveActivityService(repo, rsvps, events, jdbc, apns);
        when(repo.findByUserIdAndActivityId(anyLong(), any())).thenReturn(Optional.empty());
    }

    private UserEvent event(UserEvent.Status status, Instant ends) {
        UserEvent e = new UserEvent();
        e.setStatus(status);
        e.setStartsAt(NOW.plus(Duration.ofHours(1)));
        e.setEndsAt(ends);
        return e;
    }

    private EventRsvp rsvp(EventRsvp.Status s) {
        EventRsvp r = new EventRsvp();
        r.setStatus(s);
        return r;
    }

    private LiveActivityService.Registration eventReg(String id) {
        return new LiveActivityService.Registration(id, LiveActivity.Kind.EVENT, 7L, "abcd1234");
    }

    @Test
    void goingUserRegistersEventActivity() {
        when(rsvps.findByEventIdAndUserId(7L, 1L)).thenReturn(Optional.of(rsvp(EventRsvp.Status.GOING)));
        when(events.findById(7L)).thenReturn(Optional.of(event(UserEvent.Status.ACTIVE, NOW.plus(Duration.ofHours(3)))));
        service.register(1L, eventReg("A-1"), NOW);
        ArgumentCaptor<LiveActivity> c = ArgumentCaptor.forClass(LiveActivity.class);
        verify(repo).saveAndFlush(c.capture());
        assertEquals(1L, c.getValue().getUserId());
        assertEquals("abcd1234", c.getValue().getPushToken());
        assertEquals(NOW.plus(Duration.ofHours(4)), c.getValue().getExpiresAt());
    }

    @Test
    void nonGoingUserCannotStartActivityForOthersEvent() {
        when(rsvps.findByEventIdAndUserId(7L, 2L)).thenReturn(Optional.of(rsvp(EventRsvp.Status.INTERESTED)));
        ApiException ex = assertThrows(ApiException.class, () -> service.register(2L, eventReg("A-2"), NOW));
        assertEquals("LIVE_ACTIVITY_REF_INVALID", ex.code());
        verify(repo, never()).saveAndFlush(any());
    }

    @Test
    void noRsvpIsRejected() {
        when(rsvps.findByEventIdAndUserId(7L, 3L)).thenReturn(Optional.empty());
        assertThrows(ApiException.class, () -> service.register(3L, eventReg("A-3"), NOW));
    }

    @Test
    void cancelledOrEndedEventIsRejected() {
        when(rsvps.findByEventIdAndUserId(7L, 1L)).thenReturn(Optional.of(rsvp(EventRsvp.Status.GOING)));
        when(events.findById(7L)).thenReturn(Optional.of(event(UserEvent.Status.CANCELLED, NOW.plus(Duration.ofHours(3)))));
        assertThrows(ApiException.class, () -> service.register(1L, eventReg("A-4"), NOW));
        when(events.findById(7L)).thenReturn(Optional.of(event(UserEvent.Status.ACTIVE, NOW.minus(Duration.ofHours(2)))));
        assertThrows(ApiException.class, () -> service.register(1L, eventReg("A-5"), NOW));
    }

    @Test
    void examOfAnotherUserIsRejected() {
        when(jdbc.queryForList(any(String.class), eq(Timestamp.class), eq(9L), eq(5L))).thenReturn(List.of());
        ApiException ex = assertThrows(ApiException.class, () -> service.register(5L,
                new LiveActivityService.Registration("X-1", LiveActivity.Kind.EXAM, 9L, null), NOW));
        assertEquals("LIVE_ACTIVITY_REF_INVALID", ex.code());
    }

    @Test
    void ownExamRegisters() {
        when(jdbc.queryForList(any(String.class), eq(Timestamp.class), eq(9L), eq(5L)))
                .thenReturn(List.of(Timestamp.from(NOW.plus(Duration.ofHours(2)))));
        service.register(5L, new LiveActivityService.Registration("X-2", LiveActivity.Kind.EXAM, 9L, null), NOW);
        verify(repo).saveAndFlush(any());
    }

    @Test
    void limitPerUserEnforcedButExistingActivityUpdatesIdempotently() {
        when(rsvps.findByEventIdAndUserId(7L, 1L)).thenReturn(Optional.of(rsvp(EventRsvp.Status.GOING)));
        when(events.findById(7L)).thenReturn(Optional.of(event(UserEvent.Status.ACTIVE, NOW.plus(Duration.ofHours(3)))));
        when(repo.countActive(1L, NOW)).thenReturn((long) LiveActivityService.MAX_ACTIVE_PER_USER);
        ApiException ex = assertThrows(ApiException.class, () -> service.register(1L, eventReg("NEW"), NOW));
        assertEquals("LIVE_ACTIVITY_LIMIT", ex.code());
        // Ayni activityId ile tekrar (jeton yenileme) sinira takilmaz.
        LiveActivity existing = new LiveActivity();
        existing.setUserId(1L);
        existing.setActivityId("OLD");
        when(repo.findByUserIdAndActivityId(1L, "OLD")).thenReturn(Optional.of(existing));
        service.register(1L, new LiveActivityService.Registration("OLD", LiveActivity.Kind.EVENT, 7L, "newtoken1"), NOW);
        assertEquals("newtoken1", existing.getPushToken());
    }

    @Test
    void endClearsTokenAndUnknownIsNoop() {
        LiveActivity a = new LiveActivity();
        a.setPushToken("t");
        when(repo.findByUserIdAndActivityId(1L, "E")).thenReturn(Optional.of(a));
        service.end(1L, "E", NOW);
        assertNull(a.getPushToken());
        assertNotNull(a.getEndedAt());
        service.end(1L, "MISSING", NOW);
    }

    @Test
    void endForRefSendsApnsEndAndClosesRows() {
        LiveActivity a = new LiveActivity();
        a.setPushToken("tok");
        when(repo.activeForRef(LiveActivity.Kind.EVENT, 7L, NOW)).thenReturn(List.of(a));
        assertEquals(1, service.endForRef(LiveActivity.Kind.EVENT, 7L, NOW));
        verify(apns).end(eq("tok"), any());
        assertNull(a.getPushToken());
        assertNotNull(a.getEndedAt());
    }

    @Test
    void senderIsDisabledWithoutConfiguration() {
        ApnsLiveActivitySender s = new ApnsLiveActivitySender("", "", "", "", "", true);
        assertFalse(s.configured());
        assertFalse(s.update("token", java.util.Map.of()));
        assertTrue(new ApnsLiveActivitySender("K", "T", "tr.com.bukampus.app", "x", "", true).configured());
        assertFalse(new ApnsLiveActivitySender("K", "T", "tr.com.bukampus.app", "", "", true).configured());
    }
}
