package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.event.dto.EventDtos.AttendanceRow;
import edu.bingol.backend.event.dto.EventDtos.BulkEntry;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;

/** T3: yoklama + QR + hatirlatma denetim testleri. */
class AttendanceQaTest {

    private final EventService events = mock(EventService.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final EventAttendanceRepository attendance = mock(EventAttendanceRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final CheckinCodeService codes =
            new CheckinCodeService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final AttendanceService svc = new AttendanceService(events, rsvps, attendance, codes, communities);

    private final Actor user = new Actor(1L, false);
    private final Actor organizer = new Actor(99L, false);
    private final Instant start = Instant.ofEpochSecond(1_800_000_000L);
    private final Instant end = start.plus(Duration.ofHours(2));
    private final UserEvent event = new UserEvent();

    AttendanceQaTest() {
        event.setId(5L);
        event.setStartsAt(start);
        event.setEndsAt(end);
        event.setCreatedBy(99L);
        event.setStatus(UserEvent.Status.ACTIVE);
        when(events.load(5L)).thenReturn(event);
        when(events.loadVisible(any(), eq(5L))).thenReturn(event);
        when(events.requireManager(any(), any())).thenAnswer(i -> {
            Actor a = i.getArgument(0);
            if (!a.id().equals(99L)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "yetki yok");
            }
            return i.getArgument(1);
        });
    }

    private static ApiException error(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    private void going(long uid) {
        when(rsvps.findByEventIdAndUserId(5L, uid)).thenReturn(Optional.of(new EventRsvp(5L, uid, EventRsvp.Status.GOING)));
    }

    private void userWithStatus(long id, UserStatus st) {
        User u = new User();
        u.setId(id);
        u.setDisplayName("Kisi " + id);
        u.setStatus(st);
        when(communities.usersById(List.of(id))).thenReturn(Map.of(id, u));
    }

    // ---- QR: pencere siniri tam olarak dahil ----

    @Test
    void windowBoundariesAreInclusive() {
        going(1L);
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        Instant open = start.minus(Duration.ofMinutes(30));
        Instant close = end.plus(Duration.ofMinutes(30));

        svc.checkIn(user, 5L, codes.generate(5, open), open);
        svc.checkIn(user, 5L, codes.generate(5, close), close);
        assertEquals("CHECKIN_CLOSED", error(() -> svc.checkIn(user, 5L, codes.generate(5, open.minusSeconds(1)),
                open.minusSeconds(1))).code());
        assertEquals("CHECKIN_CLOSED", error(() -> svc.checkIn(user, 5L, codes.generate(5, close.plusSeconds(1)),
                close.plusSeconds(1))).code());
    }

    @Test
    void replayOfOldCodeFailsEvenInsideWindow() {
        going(1L);
        Instant issued = start.plusSeconds(10);
        String code = codes.generate(5, issued);

        // 5 dakika sonra (pencere hala acik) ayni kod gecersiz
        assertEquals("INVALID_CODE", error(() -> svc.checkIn(user, 5L, code, issued.plus(Duration.ofMinutes(5)))).code());
    }

    @Test
    void codeOfAnotherEventCannotBeReplayedHere() {
        going(1L);
        Instant now = start.plusSeconds(10);

        assertEquals("INVALID_CODE", error(() -> svc.checkIn(user, 5L, codes.generate(6, now), now)).code());
        // eventId parcasi degistirilip imza korunursa da reddedilir
        String forged = codes.generate(6, now).replaceFirst("^6\\.", "5.");
        assertEquals("INVALID_CODE", error(() -> svc.checkIn(user, 5L, forged, now)).code());
    }

    @Test
    void cancelledEventRejectsCheckInAndCodeIssue() {
        event.setStatus(UserEvent.Status.CANCELLED);
        Instant now = start.plusSeconds(10);

        assertEquals("EVENT_NOT_OPEN", error(() -> svc.issueCode(organizer, 5L, now)).code());
        assertEquals("EVENT_NOT_OPEN", error(() -> svc.checkIn(user, 5L, codes.generate(5, now), now)).code());
        assertEquals("EVENT_NOT_OPEN", error(() -> svc.mark(organizer, 5L, 2L, true, now)).code());
    }

    @Test
    void codeCheckedBeforeRsvpSoStrangersLearnNothingAboutRsvp() {
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        Instant now = start.plusSeconds(10);

        assertEquals("INVALID_CODE", error(() -> svc.checkIn(user, 5L, "5.1.zzzz", now)).code());
    }

    // ---- esli zamanli cakisma ----

    @Test
    void concurrentCheckInConflictBecomes409() {
        going(1L);
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        when(attendance.saveAndFlush(any())).thenThrow(new DataIntegrityViolationException("dup"));
        Instant now = start.plusSeconds(10);

        ApiException e = error(() -> svc.checkIn(user, 5L, codes.generate(5, now), now));

        assertEquals("CHECKIN_CONFLICT", e.code());
        assertEquals(HttpStatus.CONFLICT, e.status());
    }

    @Test
    void concurrentManualMarkConflictBecomes409NotServerError() {
        userWithStatus(2L, UserStatus.ACTIVE);
        when(attendance.findByEventIdAndUserId(5L, 2L)).thenReturn(Optional.empty());
        when(attendance.saveAndFlush(any())).thenThrow(new DataIntegrityViolationException("dup"));

        assertEquals("CHECKIN_CONFLICT", error(() -> svc.mark(organizer, 5L, 2L, true, start)).code());
    }

    // ---- elle yoklama: kullanici durumlari / IDOR ----

    @Test
    void cannotMarkSuspendedOrDeletedUsers() {
        userWithStatus(2L, UserStatus.SUSPENDED);
        userWithStatus(3L, UserStatus.DELETED);

        assertEquals("USER_NOT_FOUND", error(() -> svc.mark(organizer, 5L, 2L, true, start)).code());
        assertEquals("USER_NOT_FOUND", error(() -> svc.mark(organizer, 5L, 3L, true, start)).code());
    }

    @Test
    void bulkIsAllOrNothingOnUnknownUser() {
        userWithStatus(2L, UserStatus.ACTIVE);
        when(attendance.findByEventIdAndUserId(any(), any())).thenReturn(Optional.empty());
        when(communities.usersById(List.of(777L))).thenReturn(Map.of());

        ApiException e = error(() -> svc.bulk(organizer, 5L,
                List.of(new BulkEntry(2L, true), new BulkEntry(777L, true)), start));

        assertEquals("USER_NOT_FOUND", e.code()); // islem geri alinir (@Transactional)
    }

    @Test
    void bulkAcceptsExactly500AndRejects501() {
        List<BulkEntry> ok = java.util.stream.IntStream.range(0, 500).mapToObj(i -> new BulkEntry((long) i + 1, true)).toList();
        for (BulkEntry b : ok) {
            userWithStatus(b.userId(), UserStatus.ACTIVE);
        }
        when(attendance.findByEventIdAndUserId(any(), any())).thenReturn(Optional.empty());

        assertEquals(500, svc.bulk(organizer, 5L, ok, start).updated());
        verify(attendance, times(500)).saveAndFlush(any());
        List<BulkEntry> big = java.util.stream.IntStream.range(0, 501).mapToObj(i -> new BulkEntry((long) i + 1, true)).toList();
        assertEquals("VALIDATION_ERROR", error(() -> svc.bulk(organizer, 5L, big, start)).code());
        assertEquals("VALIDATION_ERROR", error(() -> svc.bulk(organizer, 5L, null, start)).code());
    }

    @Test
    void manualMarkAllowedAfterEventEndedButNotBeforeWindow() {
        userWithStatus(2L, UserStatus.ACTIVE);
        when(attendance.findByEventIdAndUserId(5L, 2L)).thenReturn(Optional.empty());

        svc.mark(organizer, 5L, 2L, true, end.plus(Duration.ofDays(3)));
        assertEquals("CHECKIN_CLOSED", error(() -> svc.mark(organizer, 5L, 2L, true,
                start.minus(Duration.ofMinutes(31)))).code());
    }

    @Test
    void attendanceListToleratesMissingUsersAndNullNames() {
        EventRsvp r1 = new EventRsvp(5L, 1L, EventRsvp.Status.GOING);
        EventRsvp r2 = new EventRsvp(5L, 2L, EventRsvp.Status.GOING);
        when(rsvps.findByEventIdAndStatus(5L, EventRsvp.Status.GOING)).thenReturn(List.of(r1, r2));
        when(attendance.findByEventId(5L)).thenReturn(List.of());
        User noName = new User();
        noName.setId(1L);
        when(communities.usersById(any())).thenReturn(Map.of(1L, noName)); // 2 silinmis/yok

        List<AttendanceRow> rows = svc.list(organizer, 5L);

        assertEquals(2, rows.size());
        assertEquals("Kullanıcı", rows.get(0).displayName());
    }

    // ---- CSV enjeksiyonu: ek vakalar ----

    @Test
    void csvCellEdgeCases() {
        assertEquals("\"'\rx\"", AttendanceService.cell("\rx"));
        assertEquals("\"a\"\"=b\"", AttendanceService.cell("a\"=b")); // ortadaki = tehlikesiz
        assertEquals("\"'=\"\"\"\"\"", AttendanceService.cell("=\"\"")); // formul + cift tirnak
        assertEquals("\"\"", AttendanceService.cell(""));
        assertTrue(AttendanceService.cell("'=x").startsWith("\"'="));
        assertFalse(AttendanceService.cell("  =x").startsWith("\"'")); // bosluk Excel'de formul baslatmaz
    }

    @Test
    void csvRowsAreCrlfTerminatedAndOneRowPerUser() {
        when(rsvps.findByEventIdAndStatus(5L, EventRsvp.Status.GOING))
                .thenReturn(List.of(new EventRsvp(5L, 1L, EventRsvp.Status.GOING)));
        when(attendance.findByEventId(5L)).thenReturn(List.of());
        User u = new User();
        u.setId(1L);
        u.setDisplayName("Ali\nVeli,\"X\"");
        u.setDepartment("+SUM(1)");
        when(communities.usersById(any())).thenReturn(Map.of(1L, u));

        String csv = svc.csv(organizer, 5L);

        assertTrue(csv.contains("\"Ali\nVeli,\"\"X\"\"\""));
        assertTrue(csv.contains("\"'+SUM(1)\""));
        assertTrue(csv.endsWith("\r\n"));
        assertEquals(2, csv.split("\r\n").length);
    }

    // ---- hatirlatma ----

    @Test
    void failingNotificationDoesNotAbortRemainingReminders() {
        EventRsvpRepository repo = mock(EventRsvpRepository.class);
        NotificationService notif = mock(NotificationService.class);
        EventReminderService rem = new EventReminderService(repo, notif);
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setTitle("Konferans");
        EventRsvp a = new EventRsvp(5L, 11L, EventRsvp.Status.GOING);
        a.setId(1L);
        EventRsvp b = new EventRsvp(5L, 12L, EventRsvp.Status.GOING);
        b.setId(2L);
        when(repo.hourCandidates(any(), any(), any(), any(), any()))
                .thenReturn(List.<Object[]>of(new Object[] {a, e}, new Object[] {b, e}));
        when(repo.dayCandidates(any(), any(), any(), any(), any())).thenReturn(List.of());
        when(repo.claimHour(anyLongObj())).thenReturn(1);
        doThrow(new IllegalStateException("fcm down")).when(notif)
                .sendTemplated(eq(11L), eq(NotificationType.EVENT), anyString(), any(), any(String[].class));

        int sent = rem.run(Instant.parse("2026-11-01T10:00:00Z"));

        assertEquals(1, sent);
        verify(notif).sendTemplated(eq(12L), eq(NotificationType.EVENT), eq("notif.event.reminderHour"), any(), any(String[].class));
    }

    private static Long anyLongObj() {
        return org.mockito.ArgumentMatchers.anyLong();
    }

    @Test
    void reminderIncludesLocationOnlyWhenPresent() {
        EventRsvpRepository repo = mock(EventRsvpRepository.class);
        NotificationService notif = mock(NotificationService.class);
        EventReminderService rem = new EventReminderService(repo, notif);
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setTitle("Konferans");
        e.setLocation("Salon A");
        EventRsvp a = new EventRsvp(5L, 11L, EventRsvp.Status.GOING);
        a.setId(1L);
        when(repo.hourCandidates(any(), any(), any(), any(), any())).thenReturn(List.<Object[]>of(new Object[] {a, e}));
        when(repo.dayCandidates(any(), any(), any(), any(), any())).thenReturn(List.of());
        when(repo.claimHour(1L)).thenReturn(1);

        rem.run(Instant.now());

        verify(notif).sendTemplated(eq(11L), eq(NotificationType.EVENT), anyString(), any(), eq("Konferans (Salon A)"));
    }
}
