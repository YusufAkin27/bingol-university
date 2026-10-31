package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.admin.rbac.AdminProfile;
import edu.bingol.backend.admin.rbac.PermissionMatrix;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.community.SystemAdminAudit;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.event.dto.EventDtos.UpdateEventRequest;
import edu.bingol.backend.event.extras.CoOrganizerLookup;
import edu.bingol.backend.event.extras.CoOrganizerRepository;
import edu.bingol.backend.event.extras.CoOrganizerService;
import edu.bingol.backend.event.extras.EventSeriesMemberRepository;
import edu.bingol.backend.event.extras.SeriesService;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
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

/**
 * T-041: etkinlik yonetimi CANLI kulup yetkisine bagli. Yasaklanan / cikarilan / yetkisi alinan olusturan ve kulup
 * disi ortak organizator katilimci PII'sine, duyuruya, seriye erisemez; seri kopyasi onaysiz ACTIVE olmaz; ortak
 * organizator hedefi kulup uyesi olmalidir; kulupten dusen kisinin organizator izleri temizlenir.
 */
class EventLiveClubAuthorityTest {

    private final UserEventRepository eventRepo = mock(UserEventRepository.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final CoOrganizerLookup coLookup = mock(CoOrganizerLookup.class);
    private final EventService svc = new EventService(eventRepo, rsvps, mock(OfficialEventRepository.class), communities,
            mock(NotificationService.class), mock(MediaService.class));

    private static final long CREATOR = 99L;
    private static final long CLUB = 10L;
    private final Actor creator = new Actor(CREATOR, false);
    private final Actor coOrg = new Actor(55L, false);
    private final Instant start = Instant.now().plus(Duration.ofDays(2));

    EventLiveClubAuthorityTest() {
        svc.setCoOrganizers(coLookup);
    }

    private UserEvent clubEvent() {
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setTitle("Konferans");
        e.setStartsAt(start);
        e.setEndsAt(start.plus(Duration.ofHours(2)));
        e.setCreatedBy(CREATOR);
        e.setCommunityId(CLUB);
        e.setStatus(UserEvent.Status.ACTIVE);
        when(eventRepo.findById(5L)).thenReturn(Optional.of(e));
        return e;
    }

    private void clubVisibleButNotMember(Community.Visibility v) {
        Community c = new Community();
        c.setId(CLUB);
        c.setStatus(Community.Status.ACTIVE);
        c.setVisibility(v);
        when(communities.load(CLUB)).thenReturn(c);
    }

    // ---- canManage / requireManager ----

    @Test
    void creatorWhoLostClubAuthorityCannotManageClubEvent() {
        UserEvent e = clubEvent();
        // yasaklandi / cikarildi / yetkisi alindi: MANAGE_EVENTS yok
        when(communities.can(any(), eq(CLUB), eq(ClubPermission.MANAGE_EVENTS))).thenReturn(false);
        clubVisibleButNotMember(Community.Visibility.PUBLIC);

        assertFalse(svc.canManage(creator, e));
        ApiException ex = assertThrows(ApiException.class, () -> svc.requireManager(creator, e));
        assertEquals(403, ex.status().value());
    }

    @Test
    void creatorWhoLostAccessToPrivateClubGets404() {
        UserEvent e = clubEvent();
        when(communities.can(any(), eq(CLUB), eq(ClubPermission.MANAGE_EVENTS))).thenReturn(false);
        when(communities.roleOf(CLUB, CREATOR)).thenReturn(Optional.empty());
        clubVisibleButNotMember(Community.Visibility.PRIVATE);

        ApiException ex = assertThrows(ApiException.class, () -> svc.requireManager(creator, e));

        assertEquals(404, ex.status().value());
    }

    @Test
    void creatorWithLiveClubAuthorityStillManages() {
        UserEvent e = clubEvent();
        when(communities.can(any(), eq(CLUB), eq(ClubPermission.MANAGE_EVENTS))).thenReturn(true);

        assertTrue(svc.canManage(creator, e));
        assertEquals(e, svc.requireManager(creator, e));
    }

    @Test
    void clublessLegacyEventKeepsCreatorAndCoOrganizerRule() {
        UserEvent e = clubEvent();
        e.setCommunityId(null);
        when(coLookup.isCoOrganizer(5L, 55L)).thenReturn(true);

        assertTrue(svc.canManage(creator, e));
        assertTrue(svc.canManage(coOrg, e));
        assertFalse(svc.canManage(new Actor(1L, false), e));
    }

    @Test
    void coOrganizerOutsideTheClubCannotManage() {
        UserEvent e = clubEvent();
        when(coLookup.isCoOrganizer(5L, 55L)).thenReturn(true);
        when(communities.can(any(), eq(CLUB), eq(ClubPermission.MANAGE_EVENTS))).thenReturn(false);
        when(communities.roleOf(CLUB, 55L)).thenReturn(Optional.empty()); // kulup uyesi degil

        assertFalse(svc.canManage(coOrg, e));
    }

    @Test
    void coOrganizerWhoIsActiveClubMemberManages() {
        UserEvent e = clubEvent();
        when(coLookup.isCoOrganizer(5L, 55L)).thenReturn(true);
        when(communities.can(any(), eq(CLUB), eq(ClubPermission.MANAGE_EVENTS))).thenReturn(false);
        when(communities.roleOf(CLUB, 55L)).thenReturn(Optional.of(CommunityMember.Role.MEMBER));

        assertTrue(svc.canManage(coOrg, e));
    }

    @Test
    void viewerAdminDoesNotManageButFullAdminDoesAndIsAudited() {
        UserEvent e = clubEvent();
        when(communities.can(any(), eq(CLUB), eq(ClubPermission.MANAGE_EVENTS))).thenReturn(false);
        clubVisibleButNotMember(Community.Visibility.PUBLIC);
        SystemAdminAudit audit = mock(SystemAdminAudit.class);
        svc.setAdminAudit(audit);
        Actor viewer = new Actor(7L, true, PermissionMatrix.permissionsOf(AdminProfile.VIEWER));
        Actor full = new Actor(8L, true, PermissionMatrix.permissionsOf(AdminProfile.FULL));

        assertFalse(svc.canManage(viewer, e));
        assertThrows(ApiException.class, () -> svc.requireManager(viewer, e));
        assertTrue(svc.canManage(full, e));
        svc.requireManager(full, e);

        verify(audit).record(eq(full), eq("EVENT"), eq(5L), any());
    }

    // ---- icerik degisikligi yeniden onaya ----

    @Test
    void plainMemberEditingActiveClubEventSendsItBackToReview() {
        UserEvent e = clubEvent();
        when(communities.can(any(), eq(CLUB), eq(ClubPermission.MANAGE_EVENTS))).thenReturn(true);
        when(communities.roleOf(CLUB, CREATOR)).thenReturn(Optional.of(CommunityMember.Role.MEMBER)); // staff degil
        when(communities.byIds(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());
        when(communities.blockedFor(any())).thenReturn(Set.of(-1L));
        when(rsvps.findByUserIdAndEventIdIn(anyLong(), anyCollection())).thenReturn(List.of());
        when(rsvps.countByEvents(anyCollection(), any())).thenReturn(List.of());

        svc.update(creator, 5L, new UpdateEventRequest("Yeni baslik", null, null, null, null, null, null));

        assertEquals(UserEvent.Status.PENDING_REVIEW, e.getStatus());
    }

    @Test
    void staffEditingActiveClubEventKeepsItActive() {
        UserEvent e = clubEvent();
        when(communities.can(any(), eq(CLUB), eq(ClubPermission.MANAGE_EVENTS))).thenReturn(true);
        when(communities.roleOf(CLUB, CREATOR)).thenReturn(Optional.of(CommunityMember.Role.MODERATOR));
        when(communities.byIds(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());
        when(communities.blockedFor(any())).thenReturn(Set.of(-1L));
        when(rsvps.findByUserIdAndEventIdIn(anyLong(), anyCollection())).thenReturn(List.of());
        when(rsvps.countByEvents(anyCollection(), any())).thenReturn(List.of());

        svc.update(creator, 5L, new UpdateEventRequest("Yeni baslik", null, null, null, null, null, null));

        assertEquals(UserEvent.Status.ACTIVE, e.getStatus());
    }

    // ---- seri ----

    @Test
    void seriesCopiesOfNonStaffAreNotAutoApproved() {
        EventService events = mock(EventService.class);
        UserEventRepository repo = mock(UserEventRepository.class);
        EventSeriesMemberRepository members = mock(EventSeriesMemberRepository.class);
        UserEvent src = clubEvent();
        when(events.load(5L)).thenReturn(src);
        when(events.requireManager(any(), any())).thenReturn(src);
        when(events.isStaff(creator, CLUB)).thenReturn(false);
        when(repo.findAllById(any())).thenReturn(List.of());
        ArgumentCaptor<UserEvent> saved = ArgumentCaptor.forClass(UserEvent.class);

        new SeriesService(events, repo, members).create(creator, 5L, 2, Instant.now());

        verify(repo, org.mockito.Mockito.times(2)).save(saved.capture());
        assertTrue(saved.getAllValues().stream().allMatch(c -> c.getStatus() == UserEvent.Status.PENDING_REVIEW));
    }

    @Test
    void seriesCopiesOfStaffStayActive() {
        EventService events = mock(EventService.class);
        UserEventRepository repo = mock(UserEventRepository.class);
        UserEvent src = clubEvent();
        when(events.load(5L)).thenReturn(src);
        when(events.requireManager(any(), any())).thenReturn(src);
        when(events.isStaff(creator, CLUB)).thenReturn(true);
        when(repo.findAllById(any())).thenReturn(List.of());
        ArgumentCaptor<UserEvent> saved = ArgumentCaptor.forClass(UserEvent.class);

        new SeriesService(events, repo, mock(EventSeriesMemberRepository.class)).create(creator, 5L, 1, Instant.now());

        verify(repo).save(saved.capture());
        assertEquals(UserEvent.Status.ACTIVE, saved.getValue().getStatus());
    }

    // ---- ortak organizator ----

    @Test
    void coOrganizerTargetMustBeActiveClubMember() {
        EventService events = mock(EventService.class);
        CoOrganizerRepository coRepo = mock(CoOrganizerRepository.class);
        BlockService blocks = mock(BlockService.class);
        CoOrganizerService co = new CoOrganizerService(events, coRepo, communities, blocks, mock(NotificationService.class));
        UserEvent e = clubEvent();
        when(events.load(5L)).thenReturn(e);
        when(communities.can(any(), eq(CLUB), eq(ClubPermission.MANAGE_EVENTS))).thenReturn(true); // ownerLevel
        User target = new User();
        target.setId(3L);
        target.setDisplayName("Hedef");
        target.setStatus(UserStatus.ACTIVE);
        when(communities.usersById(any())).thenReturn(Map.of(3L, target));
        when(communities.roleOf(CLUB, 3L)).thenReturn(Optional.empty()); // kulup disi

        ApiException ex = assertThrows(ApiException.class, () -> co.add(creator, 5L, 3L));

        assertEquals("CO_ORGANIZER_NOT_MEMBER", ex.code());
        verify(coRepo, never()).saveAndFlush(any());
    }

    @Test
    void coOrganizerOutsideClubCannotRunSeriesOrOwnerLevelActions() {
        EventService events = mock(EventService.class);
        CoOrganizerService co = new CoOrganizerService(events, mock(CoOrganizerRepository.class), communities,
                mock(BlockService.class), mock(NotificationService.class));
        UserEvent e = clubEvent();
        when(communities.can(any(), eq(CLUB), eq(ClubPermission.MANAGE_EVENTS))).thenReturn(false);
        // kulup etkinliginde olusturan bile MANAGE_EVENTS'siz sahip duzeyinde degil (T-041)
        assertFalse(coOwnerLevel(co, creator, e));
        assertFalse(coOwnerLevel(co, coOrg, e));
    }

    private static boolean coOwnerLevel(CoOrganizerService co, Actor a, UserEvent e) {
        try {
            var m = CoOrganizerService.class.getDeclaredMethod("ownerLevel", Actor.class, UserEvent.class);
            m.setAccessible(true);
            return (boolean) m.invoke(co, a, e);
        } catch (ReflectiveOperationException ex) {
            throw new IllegalStateException(ex);
        }
    }

    // ---- kulupten dusme temizligi ----

    @Test
    void leavingMemberLosesCoOrganizerRowsAndPrivateClubRsvps() {
        CoOrganizerRepository coRepo = mock(CoOrganizerRepository.class);
        CommunityRepository clubs = mock(CommunityRepository.class);
        Community c = new Community();
        c.setId(CLUB);
        c.setVisibility(Community.Visibility.PRIVATE);
        when(clubs.findById(CLUB)).thenReturn(Optional.of(c));
        when(eventRepo.liveIdsByCommunity(eq(CLUB), any(), any())).thenReturn(List.of(5L, 6L));
        EventRsvp going = new EventRsvp(5L, 55L, EventRsvp.Status.GOING);
        EventRsvp interested = new EventRsvp(6L, 55L, EventRsvp.Status.INTERESTED);
        when(rsvps.findByEventIdAndUserId(5L, 55L)).thenReturn(Optional.of(going));
        when(rsvps.findByEventIdAndUserId(6L, 55L)).thenReturn(Optional.of(interested));
        EventMemberLeftCleanup cleanup = new EventMemberLeftCleanup(coRepo, clubs, eventRepo, rsvps);

        int removed = cleanup.cleanup(CLUB, 55L);

        assertEquals(2, removed);
        verify(coRepo).deleteMemberOfCommunityEvents(CLUB, 55L);
        verify(eventRepo).decrementGoing(5L);
        verify(eventRepo, never()).decrementGoing(6L);
        verify(rsvps).delete(going);
        verify(rsvps).delete(interested);
    }

    @Test
    void publicClubKeepsRsvpsButStillDropsCoOrganizerRows() {
        CoOrganizerRepository coRepo = mock(CoOrganizerRepository.class);
        CommunityRepository clubs = mock(CommunityRepository.class);
        Community c = new Community();
        c.setId(CLUB);
        c.setVisibility(Community.Visibility.PUBLIC);
        when(clubs.findById(CLUB)).thenReturn(Optional.of(c));
        EventMemberLeftCleanup cleanup = new EventMemberLeftCleanup(coRepo, clubs, eventRepo, rsvps);

        assertEquals(0, cleanup.cleanup(CLUB, 55L));

        verify(coRepo).deleteMemberOfCommunityEvents(CLUB, 55L);
        verify(rsvps, never()).delete(any(EventRsvp.class));
    }
}
