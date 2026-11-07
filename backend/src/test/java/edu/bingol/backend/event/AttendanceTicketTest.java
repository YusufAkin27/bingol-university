package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.event.dto.EventDtos.MyTicket;
import edu.bingol.backend.event.dto.EventDtos.ScanResult;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** Katilimci bileti (kisisel QR) ve organizator tarayicisi. */
class AttendanceTicketTest {

    private final EventService events = mock(EventService.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final EventAttendanceRepository attendance = mock(EventAttendanceRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final CheckinCodeService codes =
            new CheckinCodeService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final AttendanceService svc = new AttendanceService(events, rsvps, attendance, codes, communities);

    private final Actor member = new Actor(1L, false);
    private final Actor organizer = new Actor(99L, false);
    private final Instant start = Instant.ofEpochSecond(1_800_000_000L);
    private UserEvent event;

    AttendanceTicketTest() {
        UserEvent event = new UserEvent();
        event.setId(5L);
        event.setStartsAt(start);
        event.setEndsAt(start.plus(Duration.ofHours(2)));
        event.setCreatedBy(99L);
        event.setStatus(UserEvent.Status.ACTIVE);
        event.setAttendanceOpen(true);
        this.event = event;
        when(events.load(5L)).thenReturn(event);
        when(events.loadVisible(any(), org.mockito.ArgumentMatchers.eq(5L))).thenReturn(event);
        when(events.requireManager(any(), any())).thenAnswer(i -> {
            Actor a = i.getArgument(0);
            if (!a.id().equals(99L)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "yetki yok");
            }
            return i.getArgument(1);
        });
        User u = new User();
        u.setId(1L);
        u.setDisplayName("Ayse");
        u.setStatus(UserStatus.ACTIVE);
        when(communities.usersById(List.of(1L))).thenReturn(Map.of(1L, u));
    }

    private void rsvp(EventRsvp.Status s) {
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(new EventRsvp(5L, 1L, s)));
    }

    @Test
    void ticketOnlyForApprovedAttendee() {
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        assertEquals("NOT_RSVPED", assertThrows(ApiException.class, () -> svc.issueTicket(member, 5L, start)).code());
        rsvp(EventRsvp.Status.INTERESTED);
        assertEquals("NOT_RSVPED", assertThrows(ApiException.class, () -> svc.issueTicket(member, 5L, start)).code());
        rsvp(EventRsvp.Status.GOING);
        MyTicket t = svc.issueTicket(member, 5L, start.minus(Duration.ofDays(2)));
        assertTrue(t.qrPayload().startsWith("bingol-ticket:5.1."));
    }

    @Test
    void organizerScanMarksPresentAndSecondScanIsAlready() {
        rsvp(EventRsvp.Status.GOING);
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        Instant now = start.plusSeconds(120);
        String payload = "bingol-ticket:" + codes.generateTicket(5, 1, now.minusSeconds(90));

        ScanResult r = svc.scan(organizer, 5L, payload, now);
        assertEquals("MARKED", r.status());
        assertEquals("Ayse", r.displayName());
        verify(attendance).saveAndFlush(org.mockito.ArgumentMatchers.argThat(a ->
                a.isPresent() && a.getMarkedBy().equals(99L) && a.getMethod() == EventAttendance.Method.QR));

        EventAttendance existing = new EventAttendance();
        existing.setPresent(true);
        existing.setMarkedAt(now);
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(existing));
        assertEquals("ALREADY", svc.scan(organizer, 5L, payload, now).status());
    }

    @Test
    void scanRejectsNonOrganizerExpiredForgedAndOutsideWindow() {
        rsvp(EventRsvp.Status.GOING);
        Instant now = start.plusSeconds(120);
        String good = codes.generateTicket(5, 1, now);
        assertEquals(HttpStatus.FORBIDDEN, assertThrows(ApiException.class, () -> svc.scan(member, 5L, good, now)).status());
        // suresi dolmus (5 pencere = 300 sn; 400 sn sonra)
        assertEquals("INVALID_CODE", assertThrows(ApiException.class, () -> svc.scan(organizer, 5L, good, now.plusSeconds(400))).code());
        // sahte imza / baska etkinlik / baska kullanici
        assertEquals("INVALID_CODE", assertThrows(ApiException.class, () -> svc.scan(organizer, 5L, good + "x", now)).code());
        String otherUser = good.replace("5.1.", "5.2.");
        assertEquals("INVALID_CODE", assertThrows(ApiException.class, () -> svc.scan(organizer, 5L, otherUser, now)).code());
        // etkinlik penceresi disi: sahip yoklamayi ACMADIYSA kapali (sahip actiysa pencere uygulanmaz)
        event.setAttendanceOpen(false);
        String early = codes.generateTicket(5, 1, start.minus(Duration.ofHours(3)));
        assertEquals("ATTENDANCE_NOT_OPEN", assertThrows(ApiException.class,
                () -> svc.scan(organizer, 5L, early, start.minus(Duration.ofHours(3)))).code());
        verify(attendance, never()).saveAndFlush(any());
    }

    @Test
    void scanRejectsPersonWhoLeftTheEvent() {
        rsvp(EventRsvp.Status.INTERESTED);
        Instant now = start.plusSeconds(120);
        ApiException e = assertThrows(ApiException.class, () -> svc.scan(organizer, 5L, codes.generateTicket(5, 1, now), now));
        assertEquals("NOT_RSVPED_SCAN", e.code());
    }

    @Test
    void closedAttendanceHidesTicketAndRejectsScan() {
        rsvp(EventRsvp.Status.GOING);
        event.setAttendanceOpen(false);
        Instant now = start.minus(Duration.ofHours(2));
        assertEquals("ATTENDANCE_NOT_OPEN", assertThrows(ApiException.class, () -> svc.issueTicket(member, 5L, now)).code());
        assertEquals("ATTENDANCE_NOT_OPEN", assertThrows(ApiException.class,
                () -> svc.scan(organizer, 5L, codes.generateTicket(5, 1, now), now)).code());
    }

    @Test
    void moderatorWithPermissionCanScanButWithoutGetsDenied() {
        rsvp(EventRsvp.Status.GOING);
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        EventModeratorService mods = mock(EventModeratorService.class);
        svc.setModerators(mods);
        Actor mod = new Actor(7L, false);
        Instant now = start.plusSeconds(120);
        String payload = codes.generateTicket(5, 1, now);

        // yetkisiz moderator: 403 EVENT_PERMISSION_DENIED
        when(mods.isModerator(any(), org.mockito.ArgumentMatchers.eq(7L))).thenReturn(true);
        ApiException denied = assertThrows(ApiException.class, () -> svc.scan(mod, 5L, payload, now));
        assertEquals("EVENT_PERMISSION_DENIED", denied.code());
        assertEquals(HttpStatus.FORBIDDEN, denied.status());

        // yoklama yetkisi verilmis moderator okutabilir
        when(mods.has(any(), org.mockito.ArgumentMatchers.eq(7L), org.mockito.ArgumentMatchers.eq(EventModerator.Perm.TAKE_ATTENDANCE)))
                .thenReturn(true);
        assertEquals("MARKED", svc.scan(mod, 5L, payload, now).status());

        // moderator olmayan katilimci: eski requireManager kurali (403)
        assertEquals(HttpStatus.FORBIDDEN, assertThrows(ApiException.class, () -> svc.scan(member, 5L, payload, now)).status());
    }
}
