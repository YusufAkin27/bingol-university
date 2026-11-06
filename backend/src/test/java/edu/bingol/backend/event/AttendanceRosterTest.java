package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.config.JwtProperties;
import edu.bingol.backend.event.dto.EventDtos.AttendanceRoster;
import edu.bingol.backend.event.dto.EventDtos.BulkResult;
import edu.bingol.backend.event.dto.EventDtos.ScanResult;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;

/** Yeni yoklama modeli: yoklamayi alanlarin QR'i yok; liste + elle isaretleme + toplu + cok okutucu. */
class AttendanceRosterTest {

    private final EventService events = mock(EventService.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final EventAttendanceRepository attendance = mock(EventAttendanceRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final EventModeratorService moderators = mock(EventModeratorService.class);
    private final CheckinCodeService codes =
            new CheckinCodeService(new JwtProperties("test-secret-test-secret-test-secret-1234", 15, 30));
    private final AttendanceService svc = new AttendanceService(events, rsvps, attendance, codes, communities);

    private final Actor owner = new Actor(99L, false);
    private final Actor modTake = new Actor(7L, false);
    private final Actor modViewOnly = new Actor(8L, false);
    private final Actor attendee = new Actor(1L, false);
    private final Instant start = Instant.ofEpochSecond(1_800_000_000L);
    private final Instant end = start.plus(Duration.ofHours(2));
    private final Instant during = start.plusSeconds(600);
    private final UserEvent event = new UserEvent();
    private final Map<Long, EventAttendance> store = new HashMap<>();

    AttendanceRosterTest() {
        event.setId(5L);
        event.setStartsAt(start);
        event.setEndsAt(end);
        event.setCreatedBy(99L);
        event.setStatus(UserEvent.Status.ACTIVE);
        svc.setModerators(moderators);
        when(events.load(5L)).thenReturn(event);
        when(events.loadVisible(any(), eq(5L))).thenReturn(event);
        when(events.canManage(eq(owner), any())).thenReturn(true);
        when(events.requireManager(any(), any())).thenAnswer(i -> {
            Actor a = i.getArgument(0);
            if (!a.id().equals(99L)) {
                throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "yetki yok");
            }
            return i.getArgument(1);
        });
        when(moderators.has(event, 7L, EventModerator.Perm.TAKE_ATTENDANCE)).thenReturn(true);
        when(moderators.has(event, 8L, EventModerator.Perm.VIEW_ATTENDEES)).thenReturn(true);
        when(moderators.isModerator(event, 7L)).thenReturn(true);
        when(moderators.isModerator(event, 8L)).thenReturn(true);
        for (long id : new long[] {1, 2, 3, 4}) {
            User u = new User();
            u.setId(id);
            u.setDisplayName("Kisi " + id);
            u.setStatus(UserStatus.ACTIVE);
            when(communities.usersById(List.of(id))).thenReturn(Map.of(id, u));
            when(rsvps.findByEventIdAndUserId(5L, id))
                    .thenReturn(Optional.of(new EventRsvp(5L, id, EventRsvp.Status.GOING)));
        }
        when(attendance.findByEventIdAndUserId(eq(5L), any())).thenAnswer(i -> Optional.ofNullable(store.get(i.<Long>getArgument(1))));
        when(attendance.findByEventId(5L)).thenAnswer(i -> List.copyOf(store.values()));
        when(attendance.saveAndFlush(any())).thenAnswer(i -> {
            EventAttendance a = i.getArgument(0);
            store.put(a.getUserId(), a);
            return a;
        });
        org.mockito.Mockito.doAnswer(i -> {
            store.remove(i.<EventAttendance>getArgument(0).getUserId());
            return null;
        }).when(attendance).delete(any(EventAttendance.class));
        when(rsvps.findByEventIdAndStatus(5L, EventRsvp.Status.GOING)).thenAnswer(i -> List.of(
                new EventRsvp(5L, 1L, EventRsvp.Status.GOING), new EventRsvp(5L, 2L, EventRsvp.Status.GOING),
                new EventRsvp(5L, 3L, EventRsvp.Status.GOING), new EventRsvp(5L, 4L, EventRsvp.Status.GOING)));
        Map<Long, User> all = new HashMap<>();
        for (long id : new long[] {1, 2, 3, 4, 7, 99}) {
            User u = new User();
            u.setId(id);
            u.setDisplayName("Kisi " + id);
            u.setStatus(UserStatus.ACTIVE);
            all.put(id, u);
        }
        when(communities.usersById(org.mockito.ArgumentMatchers.<java.util.Collection<Long>>any())).thenAnswer(i -> {
            Map<Long, User> out = new HashMap<>();
            for (Long id : i.<java.util.Collection<Long>>getArgument(0)) {
                if (all.containsKey(id)) {
                    out.put(id, all.get(id));
                }
            }
            return out;
        });
        when(communities.blockedFor(any())).thenReturn(java.util.Set.of());
        when(communities.profileExtras(any(), any(), any())).thenReturn(Map.of());
    }

    private static ApiException error(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    @Test
    void ownerAndModeratorsGetNoTicketOnlyAttendeeDoes() {
        event.setAttendanceOpen(true);
        assertEquals("TICKET_NOT_FOR_STAFF", error(() -> svc.issueTicket(owner, 5L, during)).code());
        assertEquals("TICKET_NOT_FOR_STAFF", error(() -> svc.issueTicket(modTake, 5L, during)).code());
        assertEquals("TICKET_NOT_FOR_STAFF", error(() -> svc.issueTicket(modViewOnly, 5L, during)).code());
        assertTrue(svc.issueTicket(attendee, 5L, during).qrPayload().startsWith("bingol-ticket:5.1."));
    }

    @Test
    void manualStatusPresentAbsentAndUndo() {
        svc.mark(owner, 5L, 1L, "PRESENT", during);
        assertTrue(store.get(1L).isPresent());
        assertEquals(EventAttendance.Method.MANUAL, store.get(1L).getMethod());
        assertEquals(99L, store.get(1L).getMarkedBy());
        svc.mark(modTake, 5L, 1L, "ABSENT", during);
        assertEquals(false, store.get(1L).isPresent());
        assertEquals(7L, store.get(1L).getMarkedBy());
        svc.mark(owner, 5L, 1L, "NONE", during);
        assertEquals(null, store.get(1L)); // sifirla = bekliyor
        assertEquals("VALIDATION_ERROR", error(() -> svc.mark(owner, 5L, 1L, "MAYBE", during)).code());
    }

    @Test
    void manualMarkingAllowedAfterEventEndedButNotBeforeWindow() {
        Instant muchLater = end.plus(Duration.ofDays(3));
        svc.mark(owner, 5L, 2L, "PRESENT", muchLater);
        assertTrue(store.get(2L).isPresent());
        assertEquals("CHECKIN_CLOSED", error(() -> svc.mark(owner, 5L, 3L, "PRESENT", start.minus(Duration.ofHours(2)))).code());
    }

    @Test
    void permissionMatrixForManualMarkingAndList() {
        // yalniz VIEW_ATTENDEES: listeyi gorur, isaretleyemez
        assertEquals("EVENT_PERMISSION_DENIED", error(() -> svc.mark(modViewOnly, 5L, 1L, "PRESENT", during)).code());
        assertEquals("EVENT_PERMISSION_DENIED", error(() -> svc.bulkStatus(modViewOnly, 5L, "ABSENT", null, true, during)).code());
        assertEquals(4, svc.roster(modViewOnly, 5L).total());
        // TAKE_ATTENDANCE: isaretler ve listeyi gorur
        svc.mark(modTake, 5L, 1L, "PRESENT", during);
        assertEquals(1, svc.roster(modTake, 5L).present());
        // katilimci / yabanci: reddedilir
        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.mark(attendee, 5L, 1L, "PRESENT", during)).status());
        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.roster(attendee, 5L)).status());
    }

    @Test
    void rosterCountsAndBulkRestMarksOnlyPending() {
        svc.mark(owner, 5L, 1L, "PRESENT", during);
        svc.mark(owner, 5L, 2L, "ABSENT", during);
        AttendanceRoster r = svc.roster(owner, 5L);
        assertEquals(4, r.total());
        assertEquals(1, r.present());
        assertEquals(1, r.absent());
        assertEquals(2, r.pending());
        assertEquals("PRESENT", r.rows().stream().filter(x -> x.userId() == 1L).findFirst().orElseThrow().status());

        BulkResult b = svc.bulkStatus(owner, 5L, "ABSENT", null, true, during);
        assertEquals(2, b.updated());
        r = svc.roster(owner, 5L);
        assertEquals(1, r.present());
        assertEquals(3, r.absent());
        assertEquals(0, r.pending());
        assertEquals("VALIDATION_ERROR", error(() -> svc.bulkStatus(owner, 5L, "ABSENT", List.of(), false, during)).code());
    }

    @Test
    void scanByTwoScannersSecondGetsAlreadyAfterConflict() {
        event.setAttendanceOpen(true);
        String payload = codes.generateTicket(5, 1, during);
        // ilk deneme: baska okutucu once yazdi -> benzersiz kisit; yeniden denemede kayit gorunur
        EventAttendance other = new EventAttendance();
        other.setEventId(5L);
        other.setUserId(1L);
        other.setPresent(true);
        other.setMethod(EventAttendance.Method.QR);
        other.setMarkedBy(7L);
        other.setMarkedAt(during);
        org.mockito.Mockito.doAnswer(i -> {
            store.put(1L, other);
            throw new DataIntegrityViolationException("uq");
        }).when(attendance).saveAndFlush(any());
        ScanResult r = svc.scan(owner, 5L, payload, during.plusSeconds(1));
        assertEquals("ALREADY", r.status());
        verify(attendance, times(1)).saveAndFlush(any());
    }

    @Test
    void scanThenManualResetKeepsQrScannerAndScanOverridesAbsent() {
        event.setAttendanceOpen(true);
        svc.mark(modTake, 5L, 1L, "ABSENT", during);
        ScanResult r = svc.scan(modTake, 5L, codes.generateTicket(5, 1, during), during);
        assertEquals("MARKED", r.status());
        assertEquals(EventAttendance.Method.QR, store.get(1L).getMethod());
        assertEquals(7L, store.get(1L).getMarkedBy()); // okutan kisi kaydi
        // zaten geldiyse elle "geldi" kaynagi bozmaz
        svc.mark(owner, 5L, 1L, "PRESENT", during);
        assertEquals(EventAttendance.Method.QR, store.get(1L).getMethod());
        verify(attendance, never()).delete(any(EventAttendance.class));
    }
}
