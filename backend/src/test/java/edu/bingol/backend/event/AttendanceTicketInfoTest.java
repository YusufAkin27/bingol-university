package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.config.WalletProperties;
import edu.bingol.backend.event.dto.EventDtos.TicketInfo;
import edu.bingol.backend.user.User;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;

/** T1 "Biletim": GET /events/{id}/ticket bilet verisi (QR yok; yalniz onayli katilimci). */
class AttendanceTicketInfoTest {

    private final EventService events = mock(EventService.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final AttendanceService svc = new AttendanceService(events, rsvps, mock(EventAttendanceRepository.class),
            new CheckinCodeService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30)), communities);
    private final Actor member = new Actor(1L, false);
    private final Instant start = Instant.ofEpochSecond(1_800_000_000L);
    private final UserEvent event = new UserEvent();

    AttendanceTicketInfoTest() {
        event.setId(5L);
        event.setTitle("Kodlama Gecesi");
        event.setLocation("Amfi 1");
        event.setStartsAt(start);
        event.setEndsAt(start.plus(Duration.ofHours(2)));
        event.setCreatedBy(99L);
        event.setStatus(UserEvent.Status.ACTIVE);
        when(events.loadVisible(any(), org.mockito.ArgumentMatchers.eq(5L))).thenReturn(event);
        User u = new User();
        u.setId(1L);
        u.setDisplayName("Ayse");
        User o = new User();
        o.setId(99L);
        o.setDisplayName("Kulup Baskani");
        when(communities.usersById(List.of(1L, 99L))).thenReturn(Map.of(1L, u, 99L, o));
    }

    private void rsvp(EventRsvp.Status s) {
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(new EventRsvp(5L, 1L, s)));
    }

    @Test
    void onlyGoingAttendeeGetsTicket() {
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        assertEquals("NOT_RSVPED", assertThrows(ApiException.class, () -> svc.ticketInfo(member, 5L, start)).code());
        rsvp(EventRsvp.Status.INTERESTED);
        assertEquals("NOT_RSVPED", assertThrows(ApiException.class, () -> svc.ticketInfo(member, 5L, start)).code());
        rsvp(EventRsvp.Status.GOING);
        TicketInfo t = svc.ticketInfo(member, 5L, start.minus(Duration.ofDays(1)));
        assertEquals("VALID", t.state());
        assertEquals("Ayse", t.holderName());
        assertEquals("Kulup Baskani", t.organizerName());
        assertEquals("Amfi 1", t.location());
    }

    @Test
    void staffHasNoTicket() {
        rsvp(EventRsvp.Status.GOING);
        when(events.canManage(any(), any())).thenReturn(true);
        assertEquals("TICKET_NOT_FOR_STAFF", assertThrows(ApiException.class, () -> svc.ticketInfo(member, 5L, start)).code());
    }

    @Test
    void endedAndCancelledStates() {
        rsvp(EventRsvp.Status.GOING);
        assertEquals("ENDED", svc.ticketInfo(member, 5L, start.plus(Duration.ofHours(3))).state());
        event.setStatus(UserEvent.Status.CANCELLED);
        assertEquals("CANCELLED", svc.ticketInfo(member, 5L, start).state());
    }

    @Test
    void walletFlagsDefaultOffAndNeedMasterSwitch() {
        rsvp(EventRsvp.Status.GOING);
        assertFalse(svc.ticketInfo(member, 5L, start).wallet().apple());
        svc.setWallet(new WalletProperties(false, true, true));
        assertFalse(svc.ticketInfo(member, 5L, start).wallet().google());
        svc.setWallet(new WalletProperties(true, true, false));
        TicketInfo t = svc.ticketInfo(member, 5L, start);
        assertTrue(t.wallet().apple());
        assertFalse(t.wallet().google());
    }
}
