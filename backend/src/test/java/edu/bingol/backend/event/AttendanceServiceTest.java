package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.event.dto.EventDtos.AttendanceRow;
import edu.bingol.backend.event.dto.EventDtos.BulkEntry;
import edu.bingol.backend.event.dto.EventDtos.CheckinCode;
import edu.bingol.backend.event.dto.EventDtos.MyAttendance;
import edu.bingol.backend.user.User;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class AttendanceServiceTest {

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
    private UserEvent event;

    AttendanceServiceTest() {
        event = new UserEvent();
        event.setId(5L);
        event.setStartsAt(start);
        event.setEndsAt(end);
        event.setCreatedBy(99L);
        event.setStatus(UserEvent.Status.ACTIVE);
        when(events.load(5L)).thenReturn(event);
        when(events.loadVisible(any(), org.mockito.ArgumentMatchers.eq(5L))).thenReturn(event);
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

    private void going(Long userId) {
        when(rsvps.findByEventIdAndUserId(5L, userId))
                .thenReturn(Optional.of(new EventRsvp(5L, userId, EventRsvp.Status.GOING)));
    }

    // ---- QR kodu uretimi ----

    @Test
    void onlyOrganizerGetsCode() {
        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.issueCode(user, 5L, start)).status());

        CheckinCode c = svc.issueCode(organizer, 5L, start);
        assertTrue(c.qrPayload().endsWith(c.code()));
        assertEquals(60, c.validForSeconds());
        assertTrue(c.expiresAt().isAfter(start));
    }

    @Test
    void codeNotIssuedOutsideWindow() {
        assertEquals("CHECKIN_CLOSED", error(() -> svc.issueCode(organizer, 5L, start.minus(Duration.ofMinutes(31)))).code());
        assertEquals("CHECKIN_CLOSED", error(() -> svc.issueCode(organizer, 5L, end.plus(Duration.ofMinutes(31)))).code());
        svc.issueCode(organizer, 5L, start.minus(Duration.ofMinutes(29)));
        svc.issueCode(organizer, 5L, end.plus(Duration.ofMinutes(29)));
    }

    // ---- QR ile yoklama ----

    @Test
    void checkInWritesQrAttendanceForGoingUser() {
        going(1L);
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        Instant now = start.plusSeconds(100);

        MyAttendance r = svc.checkIn(user, 5L, codes.generate(5, now), now);

        assertEquals(Boolean.TRUE, r.present());
        assertEquals(EventAttendance.Method.QR, r.method());
        verify(attendance).saveAndFlush(org.mockito.ArgumentMatchers.argThat(a ->
                a.isPresent() && a.getMarkedBy().equals(1L) && a.getMethod() == EventAttendance.Method.QR
                        && a.getMarkedAt().equals(now)));
    }

    @Test
    void secondCheckInIsIdempotent() {
        going(1L);
        EventAttendance existing = new EventAttendance();
        existing.setEventId(5L);
        existing.setUserId(1L);
        existing.setPresent(true);
        existing.setMethod(EventAttendance.Method.QR);
        existing.setMarkedBy(1L);
        existing.setMarkedAt(start);
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(existing));
        Instant now = start.plusSeconds(100);

        MyAttendance r = svc.checkIn(user, 5L, codes.generate(5, now), now);

        assertEquals(Boolean.TRUE, r.present());
        assertEquals(start, r.markedAt());
        verify(attendance, never()).saveAndFlush(any());
    }

    @Test
    void checkInRequiresGoingRsvp() {
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        Instant now = start.plusSeconds(100);

        ApiException e = error(() -> svc.checkIn(user, 5L, codes.generate(5, now), now));
        assertEquals("NOT_RSVPED", e.code());
        assertEquals(HttpStatus.FORBIDDEN, e.status());

        when(rsvps.findByEventIdAndUserId(5L, 1L))
                .thenReturn(Optional.of(new EventRsvp(5L, 1L, EventRsvp.Status.INTERESTED)));
        assertEquals("NOT_RSVPED", error(() -> svc.checkIn(user, 5L, codes.generate(5, now), now)).code());
    }

    @Test
    void checkInRejectsOutsideWindow() {
        going(1L);
        Instant early = start.minus(Duration.ofMinutes(31));
        Instant late = end.plus(Duration.ofMinutes(31));

        assertEquals("CHECKIN_CLOSED", error(() -> svc.checkIn(user, 5L, codes.generate(5, early), early)).code());
        assertEquals("CHECKIN_CLOSED", error(() -> svc.checkIn(user, 5L, codes.generate(5, late), late)).code());
    }

    @Test
    void checkInRejectsExpiredWrongOrForgedCode() {
        going(1L);
        Instant issued = start.plusSeconds(10);
        String code = codes.generate(5, issued);
        Instant now = issued.plusSeconds(61);

        assertEquals("INVALID_CODE", error(() -> svc.checkIn(user, 5L, code, now)).code());
        assertEquals("INVALID_CODE", error(() -> svc.checkIn(user, 5L, codes.generate(6, now), now)).code());
        assertEquals("INVALID_CODE", error(() -> svc.checkIn(user, 5L, "5.1.abc", now)).code());
        verify(attendance, never()).saveAndFlush(any());
    }

    @Test
    void qrCheckInOverridesManualAbsent() {
        going(1L);
        EventAttendance absent = new EventAttendance();
        absent.setEventId(5L);
        absent.setUserId(1L);
        absent.setPresent(false);
        absent.setMethod(EventAttendance.Method.MANUAL);
        absent.setMarkedBy(99L);
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(absent));
        Instant now = start.plusSeconds(100);

        svc.checkIn(user, 5L, codes.generate(5, now), now);

        assertTrue(absent.isPresent());
        assertEquals(EventAttendance.Method.QR, absent.getMethod());
    }

    // ---- elle yoklama ----

    private void activeUser(Long id) {
        User u = new User();
        u.setId(id);
        u.setDisplayName("Kisi " + id);
        when(communities.usersById(List.of(id))).thenReturn(Map.of(id, u));
    }

    @Test
    void manualMarkRequiresOrganizer() {
        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.mark(user, 5L, 2L, true, start)).status());
        verify(attendance, never()).save(any());
    }

    @Test
    void manualMarkRecordsWhoAndHow() {
        activeUser(2L);
        when(attendance.findByEventIdAndUserId(5L, 2L)).thenReturn(Optional.empty());

        svc.mark(organizer, 5L, 2L, true, start.plusSeconds(5));

        verify(attendance).save(org.mockito.ArgumentMatchers.argThat(a ->
                a.isPresent() && a.getUserId().equals(2L) && a.getMarkedBy().equals(99L)
                        && a.getMethod() == EventAttendance.Method.MANUAL));
    }

    @Test
    void manualMarkRejectedBeforeWindowOpens() {
        activeUser(2L);

        assertEquals("CHECKIN_CLOSED",
                error(() -> svc.mark(organizer, 5L, 2L, true, start.minus(Duration.ofHours(2)))).code());
    }

    @Test
    void manualMarkOfUnknownUserFails() {
        when(communities.usersById(List.of(2L))).thenReturn(Map.of());

        assertEquals("USER_NOT_FOUND", error(() -> svc.mark(organizer, 5L, 2L, true, start)).code());
    }

    @Test
    void bulkMarksAllEntries() {
        activeUser(2L);
        activeUser(3L);
        when(attendance.findByEventIdAndUserId(any(), any())).thenReturn(Optional.empty());

        var res = svc.bulk(organizer, 5L, List.of(new BulkEntry(2L, true), new BulkEntry(3L, false)), start);

        assertEquals(2, res.updated());
        verify(attendance, times(2)).save(any());
    }

    @Test
    void bulkRejectsEmptyAndOversizedRequests() {
        assertEquals("VALIDATION_ERROR", error(() -> svc.bulk(organizer, 5L, List.of(), start)).code());
        List<BulkEntry> big = java.util.stream.IntStream.range(0, 501).mapToObj(i -> new BulkEntry((long) i, true)).toList();
        assertEquals("VALIDATION_ERROR", error(() -> svc.bulk(organizer, 5L, big, start)).code());
    }

    @Test
    void listIsOrganizerOnly() {
        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.list(user, 5L)).status());
        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.csv(user, 5L)).status());
    }

    @Test
    void listShowsGoingUsersAndWalkIns() {
        EventRsvp r = new EventRsvp(5L, 1L, EventRsvp.Status.GOING);
        when(rsvps.findByEventIdAndStatus(5L, EventRsvp.Status.GOING)).thenReturn(List.of(r));
        EventAttendance walkIn = new EventAttendance();
        walkIn.setUserId(2L);
        walkIn.setPresent(true);
        walkIn.setMethod(EventAttendance.Method.MANUAL);
        walkIn.setMarkedBy(99L);
        walkIn.setMarkedAt(start);
        when(attendance.findByEventId(5L)).thenReturn(List.of(walkIn));
        User u1 = new User();
        u1.setId(1L);
        u1.setDisplayName("Ali");
        User u2 = new User();
        u2.setId(2L);
        u2.setDisplayName("Veli");
        User org = new User();
        org.setId(99L);
        org.setDisplayName("Organizator");
        when(communities.usersById(any())).thenReturn(Map.of(1L, u1, 2L, u2, 99L, org));

        List<AttendanceRow> rows = svc.list(organizer, 5L);

        assertEquals(2, rows.size());
        assertEquals("Ali", rows.get(0).displayName());
        assertFalse(rows.get(0).present());
        assertEquals(EventRsvp.Status.GOING, rows.get(0).rsvpStatus());
        assertEquals("Veli", rows.get(1).displayName());
        assertTrue(rows.get(1).present());
        assertEquals("Organizator", rows.get(1).markedByName());
    }

    // ---- CSV ----

    @Test
    void csvCellsAreQuotedAndFormulaInjectionIsNeutralised() {
        assertEquals("\"Ali\"", AttendanceService.cell("Ali"));
        assertEquals("\"\"\"x\"\"\"", AttendanceService.cell("\"x\""));
        assertEquals("\"'=HYPERLINK(\"\"http://e\"\")\"", AttendanceService.cell("=HYPERLINK(\"http://e\")"));
        assertEquals("\"'+1\"", AttendanceService.cell("+1"));
        assertEquals("\"'-1\"", AttendanceService.cell("-1"));
        assertEquals("\"'@SUM(A1)\"", AttendanceService.cell("@SUM(A1)"));
        assertEquals("\"'\tx\"", AttendanceService.cell("\tx"));
        assertEquals("\"\"", AttendanceService.cell(null));
        assertEquals("\"a,b\nc\"", AttendanceService.cell("a,b\nc"));
    }

    @Test
    void csvContainsHeaderAndEscapedRows() {
        when(rsvps.findByEventIdAndStatus(5L, EventRsvp.Status.GOING))
                .thenReturn(List.of(new EventRsvp(5L, 1L, EventRsvp.Status.GOING)));
        when(attendance.findByEventId(5L)).thenReturn(List.of());
        User u = new User();
        u.setId(1L);
        u.setDisplayName("=cmd|' /C calc'!A0");
        when(communities.usersById(any())).thenReturn(Map.of(1L, u));

        String csv = svc.csv(organizer, 5L);

        assertTrue(csv.startsWith("userId,name,"));
        assertTrue(csv.contains("\"'=cmd|' /C calc'!A0\""));
        assertFalse(csv.contains(",\"=cmd"));
    }

    @Test
    void myAttendanceReportsWindowAndRecord() {
        going(1L);
        when(attendance.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());

        MyAttendance open = svc.mine(user, 5L, start);
        MyAttendance closed = svc.mine(user, 5L, end.plus(Duration.ofHours(2)));

        assertTrue(open.checkInOpen());
        assertFalse(closed.checkInOpen());
        assertEquals(EventRsvp.Status.GOING, open.rsvpStatus());
        assertEquals(null, open.present());
    }
}
