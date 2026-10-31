package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
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
import edu.bingol.backend.community.CommunityService.ProfileExtra;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.event.dto.EventDtos.AttendanceRow;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;

/**
 * T-044: elle yoklama yalniz GOING (ya da zaten kaydi olan) kullaniciya yazilir; RSVP'siz keyfi kimlige sahte yoklama
 * ve ad/bolum sizintisi olmaz. Liste: engelli cift gorunmez, bolum gizlilik ayarina uyar (ONLY_ME -> null).
 */
class AttendancePrivacyTest {

    private final EventService events = mock(EventService.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final EventAttendanceRepository attendance = mock(EventAttendanceRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final CheckinCodeService codes =
            new CheckinCodeService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final AttendanceService svc = new AttendanceService(events, rsvps, attendance, codes, communities);

    private final Actor organizer = new Actor(99L, false);
    private final Instant start = Instant.ofEpochSecond(1_800_000_000L);
    private final Instant now = start.plus(Duration.ofMinutes(10));
    private final UserEvent event = new UserEvent();

    AttendancePrivacyTest() {
        event.setId(5L);
        event.setStartsAt(start);
        event.setEndsAt(start.plus(Duration.ofHours(2)));
        event.setCreatedBy(99L);
        event.setStatus(UserEvent.Status.ACTIVE);
        when(events.load(5L)).thenReturn(event);
        when(events.requireManager(any(), any())).thenReturn(event);
    }

    private static User user(long id, String name, String dept) {
        User u = new User();
        u.setId(id);
        u.setDisplayName(name);
        u.setDepartment(dept);
        u.setStatus(UserStatus.ACTIVE);
        return u;
    }

    @Test
    void markingUserWithoutRsvpIsRejectedLikeUnknownUser() {
        when(communities.usersById(List.of(7L))).thenReturn(Map.of(7L, user(7, "Ayse", "Isletme")));
        when(rsvps.findByEventIdAndUserId(5L, 7L)).thenReturn(Optional.empty());
        when(attendance.findByEventIdAndUserId(5L, 7L)).thenReturn(Optional.empty());

        ApiException e = assertThrows(ApiException.class, () -> svc.mark(organizer, 5L, 7L, true, now));

        assertEquals(404, e.status().value());
        assertEquals("USER_NOT_FOUND", e.code());
        verify(attendance, never()).saveAndFlush(any());
    }

    @Test
    void interestedOnlyUserCannotBeMarkedEither() {
        when(communities.usersById(List.of(7L))).thenReturn(Map.of(7L, user(7, "Ayse", "Isletme")));
        when(rsvps.findByEventIdAndUserId(5L, 7L))
                .thenReturn(Optional.of(new EventRsvp(5L, 7L, EventRsvp.Status.INTERESTED)));
        when(attendance.findByEventIdAndUserId(5L, 7L)).thenReturn(Optional.empty());

        assertEquals("USER_NOT_FOUND", assertThrows(ApiException.class, () -> svc.mark(organizer, 5L, 7L, true, now)).code());
    }

    @Test
    void goingUserCanBeMarked() {
        when(communities.usersById(List.of(7L))).thenReturn(Map.of(7L, user(7, "Ayse", "Isletme")));
        when(rsvps.findByEventIdAndUserId(5L, 7L)).thenReturn(Optional.of(new EventRsvp(5L, 7L, EventRsvp.Status.GOING)));
        when(attendance.findByEventIdAndUserId(5L, 7L)).thenReturn(Optional.empty());

        svc.mark(organizer, 5L, 7L, true, now);

        verify(attendance).saveAndFlush(any(EventAttendance.class));
    }

    @Test
    void userWithExistingRecordCanStillBeCorrected() {
        EventAttendance rec = new EventAttendance();
        rec.setEventId(5L);
        rec.setUserId(7L);
        rec.setPresent(true);
        when(communities.usersById(List.of(7L))).thenReturn(Map.of(7L, user(7, "Ayse", "Isletme")));
        when(rsvps.findByEventIdAndUserId(5L, 7L)).thenReturn(Optional.empty());
        when(attendance.findByEventIdAndUserId(5L, 7L)).thenReturn(Optional.of(rec));

        svc.mark(organizer, 5L, 7L, false, now);

        verify(attendance).saveAndFlush(rec);
    }

    @Test
    void listHidesBlockedPairsAndRespectsDepartmentPrivacy() {
        when(rsvps.findByEventIdAndStatus(5L, EventRsvp.Status.GOING)).thenReturn(List.of(
                new EventRsvp(5L, 7L, EventRsvp.Status.GOING), new EventRsvp(5L, 8L, EventRsvp.Status.GOING),
                new EventRsvp(5L, 9L, EventRsvp.Status.GOING)));
        when(attendance.findByEventId(5L)).thenReturn(List.of());
        User gizli = user(7, "Gizli", "Hukuk");
        User acik = user(8, "Acik", "Isletme");
        User engelli = user(9, "Engelli", "Tip");
        when(communities.usersById(any())).thenReturn(Map.of(7L, gizli, 8L, acik, 9L, engelli));
        when(communities.blockedFor(organizer)).thenReturn(Set.of(9L, -1L));
        // 7 numara bolumunu ONLY_ME yapmis: profileExtras bos ProfileExtra vermez/atlar
        when(communities.profileExtras(any(), any(), any())).thenReturn(Map.of(8L, new ProfileExtra("Isletme", null)));

        List<AttendanceRow> rows = svc.list(organizer, 5L);

        assertEquals(2, rows.size());
        assertTrue(rows.stream().noneMatch(r -> r.userId() == 9L), "engelli cift listede olmamali");
        assertNull(rows.stream().filter(r -> r.userId() == 7L).findFirst().orElseThrow().department());
        assertEquals("Isletme", rows.stream().filter(r -> r.userId() == 8L).findFirst().orElseThrow().department());
        // CSV de ayni listeyi kullanir
        String csv = svc.csv(organizer, 5L);
        assertTrue(!csv.contains("Engelli") && !csv.contains("Hukuk"), csv);
    }
}
