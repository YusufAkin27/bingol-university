package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import org.junit.jupiter.api.Test;

/** Biten/iptal etkinlik kurali: endsAt anina kadar etkinlik "guncel", UTC anlariyla karsilastirilir. */
class EventLivenessTest {

    private static final ZoneId IST = ZoneId.of("Europe/Istanbul");

    private UserEvent ev(UserEvent.Status st, Instant start, Instant end) {
        UserEvent e = new UserEvent();
        e.setStatus(st);
        e.setStartsAt(start);
        e.setEndsAt(end);
        return e;
    }

    @Test
    void ongoingEventIsLiveEndedIsNot() {
        Instant now = Instant.parse("2026-11-07T10:00:00Z");
        assertTrue(EventLiveness.isLive(ev(UserEvent.Status.ACTIVE, now.minusSeconds(3600), now.plusSeconds(1)), now));
        assertFalse(EventLiveness.isLive(ev(UserEvent.Status.ACTIVE, now.minusSeconds(3600), now), now));
        assertFalse(EventLiveness.isLive(ev(UserEvent.Status.ACTIVE, now.minusSeconds(7200), now.minusSeconds(1)), now));
        assertTrue(EventLiveness.isLive(ev(UserEvent.Status.ACTIVE, now.plusSeconds(60), now.plusSeconds(600)), now));
    }

    @Test
    void cancelledOrUnpublishedIsNeverLive() {
        Instant now = Instant.parse("2026-11-07T10:00:00Z");
        for (UserEvent.Status s : new UserEvent.Status[] {UserEvent.Status.CANCELLED, UserEvent.Status.HIDDEN,
                UserEvent.Status.PENDING_REVIEW, UserEvent.Status.REJECTED}) {
            assertFalse(EventLiveness.isLive(ev(s, now.plusSeconds(60), now.plusSeconds(600)), now));
        }
    }

    @Test
    void stateNames() {
        Instant now = Instant.parse("2026-11-07T10:00:00Z");
        assertEquals("LIVE", EventLiveness.state(ev(UserEvent.Status.ACTIVE, now, now.plusSeconds(5)), now));
        assertEquals("ENDED", EventLiveness.state(ev(UserEvent.Status.ACTIVE, now.minusSeconds(9), now.minusSeconds(5)), now));
        assertEquals("CANCELLED", EventLiveness.state(ev(UserEvent.Status.CANCELLED, now, now.plusSeconds(5)), now));
        assertEquals("UNAVAILABLE", EventLiveness.state(ev(UserEvent.Status.HIDDEN, now, now.plusSeconds(5)), now));
        assertEquals("UNAVAILABLE", EventLiveness.state(null, now));
    }

    @Test
    void istanbulDayBoundariesUseUtcInstants() {
        // Etkinlik 7 Kasim 23:59 (Istanbul, UTC+3) biter: 20:59 UTC. 8 Kasim 00:00 Istanbul = 21:00 UTC => bitmis.
        Instant end = LocalDate.of(2026, 11, 7).atTime(LocalTime.of(23, 59)).atZone(IST).toInstant();
        UserEvent e = ev(UserEvent.Status.ACTIVE, end.minusSeconds(3600), end);
        Instant beforeMidnight = LocalDate.of(2026, 11, 7).atTime(23, 58).atZone(IST).toInstant();
        Instant midnight = LocalDate.of(2026, 11, 8).atStartOfDay(IST).toInstant();
        assertTrue(EventLiveness.isLive(e, beforeMidnight));
        assertFalse(EventLiveness.isLive(e, midnight));
        assertEquals(Instant.parse("2026-11-07T20:59:00Z"), end);
    }
}
