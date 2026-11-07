package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.event.dto.EventDtos.AttendanceSummary;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** Okutma olaylari: yalniz ilgili kisilere, cift okutma bir kez, yetkisiz kisi ozeti goremez. */
class AttendanceLiveEventsTest {

    private final EventService events = mock(EventService.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final EventAttendanceRepository attendance = mock(EventAttendanceRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final ChatEventBus bus = mock(ChatEventBus.class);
    private final EventModeratorRepository modRepo = mock(EventModeratorRepository.class);
    private final EventModeratorService mods = mock(EventModeratorService.class);
    private final CheckinCodeService codes =
            new CheckinCodeService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final AttendanceService svc = new AttendanceService(events, rsvps, attendance, codes, communities);
    private final Actor member = new Actor(1L, false);
    private final Actor organizer = new Actor(99L, false);
    private final Instant start = Instant.ofEpochSecond(1_800_000_000L);
    private final UserEvent event = new UserEvent();

    AttendanceLiveEventsTest() {
        event.setId(5L);
        event.setStartsAt(start);
        event.setEndsAt(start.plus(Duration.ofHours(2)));
        event.setCreatedBy(99L);
        event.setStatus(UserEvent.Status.ACTIVE);
        event.setAttendanceOpen(true);
        when(events.load(5L)).thenReturn(event);
        when(events.loadVisible(any(), eq(5L))).thenReturn(event);
        when(events.requireManager(any(), any())).thenAnswer(i -> {
            Actor a = i.getArgument(0);
            if (!a.id().equals(99L)) {
                throw new edu.bingol.backend.common.ApiException(org.springframework.http.HttpStatus.FORBIDDEN, "FORBIDDEN", "x");
            }
            return i.getArgument(1);
        });
        User u = new User();
        u.setId(1L);
        u.setDisplayName("Ayse");
        u.setStatus(UserStatus.ACTIVE);
        when(communities.usersById(List.of(1L))).thenReturn(Map.of(1L, u));
        when(communities.blockedFor(any())).thenReturn(Set.of(-1L));
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(new EventRsvp(5L, 1L, EventRsvp.Status.GOING)));
        when(rsvps.countByEventIdAndStatus(5L, EventRsvp.Status.GOING)).thenReturn(10L);
        when(attendance.countByEventIdAndPresentTrue(5L)).thenReturn(4L);
        when(modRepo.findByEventIdOrderByCreatedAtAsc(5L)).thenReturn(List.of());
        svc.setLive(new AttendanceLiveEvents(bus, attendance, rsvps, modRepo, mods, communities));
    }

    @Test
    void participantCheckInNotifiesOwnerAndParticipantOnly() {
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        Instant now = start.plusSeconds(60);
        svc.checkIn(member, 5L, codes.generate(5L, now), now);

        ArgumentCaptor<Object> p = ArgumentCaptor.forClass(Object.class);
        ArgumentCaptor<java.util.Collection<Long>> to = ArgumentCaptor.forClass(java.util.Collection.class);
        verify(bus, times(2)).publish(eq("attendance-events"), to.capture(), p.capture());
        assertEquals(Set.of(99L), Set.copyOf(to.getAllValues().get(0)));
        assertEquals(Set.of(1L), Set.copyOf(to.getAllValues().get(1)));
        AttendanceLiveEvents.Payload scan = (AttendanceLiveEvents.Payload) p.getAllValues().get(0);
        assertEquals("SCAN", scan.type());
        assertEquals("Ayse", scan.displayName());
        assertEquals(4L, scan.present());
        assertEquals(10L, scan.total());
        AttendanceLiveEvents.Payload mine = (AttendanceLiveEvents.Payload) p.getAllValues().get(1);
        assertEquals("MARKED", mine.type());
        assertEquals(scan.key(), mine.key());
        assertNull(mine.displayName());
    }

    @Test
    void organizerScanNotifiesScannedParticipantAndAlreadyPublishesNothing() {
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        Instant now = start.plusSeconds(120);
        String payload = "bingol-ticket:" + codes.generateTicket(5, 1, now);
        svc.scan(organizer, 5L, payload, now);
        verify(bus).publish(eq("attendance-events"), eq(Set.of(1L)), any());
        verify(bus).publish(eq("attendance-events"), eq(Set.of(99L)), any());

        EventAttendance existing = new EventAttendance();
        existing.setPresent(true);
        existing.setMarkedAt(now);
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(existing));
        svc.scan(organizer, 5L, payload, now);
        verify(bus, times(2)).publish(eq("attendance-events"), anyCollection(), any()); // artmadi: cift olay yok
    }

    @Test
    void blockedPairGetsCounterWithoutName() {
        when(communities.blockedFor(any())).thenReturn(Set.of(-1L, 1L));
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        Instant now = start.plusSeconds(60);
        svc.checkIn(member, 5L, codes.generate(5L, now), now);
        ArgumentCaptor<Object> p = ArgumentCaptor.forClass(Object.class);
        verify(bus, times(2)).publish(eq("attendance-events"), anyCollection(), p.capture());
        AttendanceLiveEvents.Payload scan = (AttendanceLiveEvents.Payload) p.getAllValues().get(0);
        assertNull(scan.displayName());
        assertNull(scan.userId());
        assertEquals(4L, scan.present());
    }

    @Test
    void failedCheckInPublishesNothing() {
        Instant now = start.plusSeconds(60);
        try {
            svc.checkIn(member, 5L, "wrong", now);
        } catch (edu.bingol.backend.common.ApiException expected) {
            assertEquals("INVALID_CODE", expected.code());
        }
        verify(bus, never()).publish(any(), anyCollection(), any());
    }

    @Test
    void summaryOnlyForStaff() {
        EventAttendance last = new EventAttendance();
        last.setUserId(1L);
        last.setPresent(true);
        last.setMarkedAt(start);
        when(attendance.findFirstByEventIdAndPresentTrueOrderByMarkedAtDesc(5L)).thenReturn(Optional.of(last));
        AttendanceSummary s = svc.summary(organizer, 5L);
        assertEquals(4L, s.present());
        assertEquals(10L, s.total());
        assertEquals("Ayse", s.lastName());
        assertEquals(403, org.junit.jupiter.api.Assertions.assertThrows(edu.bingol.backend.common.ApiException.class,
                () -> svc.summary(member, 5L)).status().value());
        assertTrue(true);
    }
}
