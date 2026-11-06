package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.EventModerator.Perm;
import edu.bingol.backend.event.dto.EventDtos.CreateEventRequest;
import edu.bingol.backend.event.dto.EventDtos.UpdateEventRequest;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.notification.NotificationService;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** Rol/yetki matrisi: sahip, moderator yetki kombinasyonlari, katilimci, yabanci; sahip-ozel islemler. */
class EventModeratorMatrixTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final EventModeratorRepository modRepo = mock(EventModeratorRepository.class);
    private final EventService svc = new EventService(events, rsvps, mock(OfficialEventRepository.class), communities,
            mock(NotificationService.class), mock(MediaService.class));
    private final EventModeratorService mods = new EventModeratorService(svc, events, modRepo, communities);

    private final Actor owner = new Actor(99L, false);
    private final Actor mod = new Actor(7L, false);
    private final Actor member = new Actor(1L, false);
    private final Instant start = Instant.now().plus(Duration.ofDays(2));
    private final Instant end = start.plus(Duration.ofHours(2));
    private UserEvent event;
    private int modBits;

    EventModeratorMatrixTest() {
        svc.setModerators(mods);
        event = new UserEvent();
        event.setId(5L);
        event.setTitle("Konferans");
        event.setStartsAt(start);
        event.setEndsAt(end);
        event.setCreatedBy(99L);
        event.setCommunityId(10L);
        event.setStatus(UserEvent.Status.ACTIVE);
        when(events.findById(5L)).thenReturn(Optional.of(event));
        when(events.save(any())).thenAnswer(i -> i.getArgument(0));
        when(events.saveAndFlush(any())).thenAnswer(i -> i.getArgument(0));
        // sahip = kulupte OWNER (MANAGE_EVENTS)
        when(communities.can(any(), any(), any())).thenAnswer(i -> ((Actor) i.getArgument(0)).id().equals(99L));
        when(communities.roleOf(10L, 99L)).thenReturn(Optional.of(CommunityMember.Role.OWNER));
        when(communities.roleOf(10L, 7L)).thenReturn(Optional.of(CommunityMember.Role.MEMBER));
        when(communities.roleOf(10L, 1L)).thenReturn(Optional.of(CommunityMember.Role.MEMBER));
        Community club = new Community();
        club.setId(10L);
        club.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(club);
        when(communities.blockedFor(any())).thenReturn(java.util.Set.of());
        when(communities.usersById(any())).thenReturn(Map.of());
        when(communities.namesById(any())).thenReturn(Map.of());
        EventModerator m = new EventModerator();
        m.setEventId(5L);
        m.setUserId(7L);
        when(modRepo.findByEventIdAndUserId(5L, 7L)).thenAnswer(i -> {
            m.setPermissions(modBits);
            return modBits < 0 ? Optional.empty() : Optional.of(m);
        });
    }

    private static int bits(Perm... ps) {
        int b = 0;
        for (Perm p : ps) {
            b |= p.bit;
        }
        return b;
    }

    private static ApiException denied(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    @Test
    void moderatorHasOnlyGrantedPermissions() {
        modBits = bits(Perm.TAKE_ATTENDANCE, Perm.EDIT_INFO);
        UserEvent e = svc.load(5L);
        assertEquals(true, mods.has(e, 7L, Perm.TAKE_ATTENDANCE));
        assertEquals(true, mods.has(e, 7L, Perm.EDIT_INFO));
        assertEquals(false, mods.has(e, 7L, Perm.MANAGE_REQUESTS));
        assertEquals(false, mods.has(e, 7L, Perm.EDIT_SCHEDULE));
        assertEquals(false, mods.has(e, 1L, Perm.TAKE_ATTENDANCE)); // katilimci/yabanci moderator degil
    }

    @Test
    void moderatorLosesPermissionsWhenLeavingTheClub() {
        modBits = bits(Perm.TAKE_ATTENDANCE);
        when(communities.roleOf(10L, 7L)).thenReturn(Optional.empty());
        assertEquals(false, mods.has(svc.load(5L), 7L, Perm.TAKE_ATTENDANCE));
    }

    @Test
    void ownerOnlyActionsAreDeniedToModeratorEvenWithEveryPermission() {
        modBits = bits(Perm.values());
        // iptal/kapatma/silme -> requireManager -> 403 EVENT_PERMISSION_DENIED
        ApiException e1 = denied(() -> svc.delete(mod, 5L));
        assertEquals("EVENT_PERMISSION_DENIED", e1.code());
        assertEquals(HttpStatus.FORBIDDEN, e1.status());
        assertEquals("EVENT_PERMISSION_DENIED", denied(() -> svc.setRegistrationClosed(mod, 5L, true)).code());
        // moderator yonetimi ve yoklama acma/kapama
        assertEquals("EVENT_PERMISSION_DENIED", denied(() -> mods.put(mod, 5L, 1L, java.util.List.of("TAKE_ATTENDANCE"))).code());
        assertEquals("EVENT_PERMISSION_DENIED", denied(() -> mods.remove(mod, 5L, 7L)).code());
        assertEquals("EVENT_PERMISSION_DENIED", denied(() -> mods.setAttendanceOpen(mod, 5L, true)).code());
        assertEquals("EVENT_PERMISSION_DENIED", denied(() -> mods.list(mod, 5L)).code());
    }

    @Test
    void strangerAndMemberGetPlainForbiddenNotModeratorCode() {
        modBits = -1; // moderator kaydi yok
        assertEquals("FORBIDDEN", denied(() -> svc.delete(member, 5L)).code());
        assertEquals("FORBIDDEN", denied(() -> mods.setAttendanceOpen(member, 5L, true)).code());
    }

    @Test
    void permOrOwnerGate() {
        modBits = bits(Perm.MANAGE_REQUESTS);
        assertDoesNotThrow(() -> svc.requireManagerOrPerm(mod, svc.load(5L), Perm.MANAGE_REQUESTS));
        assertEquals("EVENT_PERMISSION_DENIED", denied(() -> svc.requireManagerOrPerm(mod, svc.load(5L), Perm.SEND_ANNOUNCEMENT)).code());
        assertDoesNotThrow(() -> svc.requireManagerOrPerm(owner, svc.load(5L), Perm.SEND_ANNOUNCEMENT));
    }

    @Test
    void updateIsFieldLevelForModerators() {
        UpdateEventRequest title = new UpdateEventRequest("Yeni baslik", null, null, null, null, null, null);
        UpdateEventRequest time = new UpdateEventRequest(null, null, start.plusSeconds(3600), end.plusSeconds(3600), null, null, null);
        UpdateEventRequest capacity = new UpdateEventRequest(null, null, null, null, null, 50, null);

        modBits = bits(Perm.EDIT_INFO);
        assertDoesNotThrow(() -> svc.update(mod, 5L, title));
        assertEquals("EVENT_PERMISSION_DENIED", denied(() -> svc.update(mod, 5L, time)).code());
        assertEquals("EVENT_PERMISSION_DENIED", denied(() -> svc.update(mod, 5L, capacity)).code());

        modBits = bits(Perm.EDIT_SCHEDULE);
        assertEquals("EVENT_PERMISSION_DENIED", denied(() -> svc.update(mod, 5L, title)).code());
        assertDoesNotThrow(() -> svc.update(mod, 5L, time));

        modBits = bits(Perm.TAKE_ATTENDANCE); // hicbir duzenleme izni yok
        assertEquals("EVENT_PERMISSION_DENIED", denied(() -> svc.update(mod, 5L, title)).code());
    }

    @Test
    void onlyClubOwnerCanCreateEvents() {
        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(c);
        when(communities.roleOf(10L, 5L)).thenReturn(Optional.of(CommunityMember.Role.ADMIN));
        when(communities.roleOf(10L, 6L)).thenReturn(Optional.of(CommunityMember.Role.MODERATOR));
        CreateEventRequest req = new CreateEventRequest("Konferans", "aciklama", start, end, "Salon", null, 10L, null);
        for (long id : new long[] {1L, 5L, 6L}) {
            ApiException ex = denied(() -> svc.create(new Actor(id, false), req));
            assertEquals("EVENT_CREATE_OWNER_ONLY", ex.code());
            assertEquals(HttpStatus.FORBIDDEN, ex.status());
        }
    }

    @Test
    void permissionNamesRejectOwnerOnlyValues() {
        assertEquals("VALIDATION_ERROR", denied(() -> EventModeratorService.bits(java.util.List.of("CLOSE_EVENT"))).code());
    }
}
