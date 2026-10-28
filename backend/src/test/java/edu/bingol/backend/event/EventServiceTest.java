package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.permissions.ClubPermission;
import edu.bingol.backend.media.MediaService;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.dto.EventDtos.CreateEventRequest;
import edu.bingol.backend.event.dto.EventDtos.EventView;
import edu.bingol.backend.event.dto.EventDtos.RsvpResult;
import edu.bingol.backend.event.dto.EventDtos.UpdateEventRequest;
import edu.bingol.backend.notification.NotificationService;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;

class EventServiceTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final EventService svc = new EventService(events, rsvps, mock(OfficialEventRepository.class), communities,
            notifications, mock(MediaService.class));

    private final Actor user = new Actor(1L, false);
    private final Instant start = Instant.now().plus(Duration.ofDays(2));
    private final Instant end = start.plus(Duration.ofHours(2));

    private CreateEventRequest req(Instant s, Instant e, Integer cap, Long communityId) {
        return new CreateEventRequest("Konferans", "aciklama", s, e, "Salon", cap, communityId, null);
    }

    private ApiException error(Runnable r) {
        return assertThrows(ApiException.class, r::run);
    }

    private UserEvent activeEvent(Integer capacity, int going) {
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setTitle("Konferans");
        e.setStartsAt(start);
        e.setEndsAt(end);
        e.setCapacity(capacity);
        e.setGoingCount(going);
        e.setCreatedBy(99L);
        e.setStatus(UserEvent.Status.ACTIVE);
        when(events.findById(5L)).thenReturn(Optional.of(e));
        return e;
    }

    // ---- olusturma ----

    @Test
    void endMustBeAfterStart() {
        assertEquals("INVALID_DATES", error(() -> svc.create(user, req(start, start, null, null))).code());
        assertEquals("INVALID_DATES", error(() -> svc.create(user, req(start, start.minusSeconds(60), null, null))).code());
    }

    @Test
    void pastEventsCannotBeCreated() {
        Instant past = Instant.now().minus(Duration.ofHours(3));

        assertEquals("PAST_EVENT", error(() -> svc.create(user, req(past, past.plusSeconds(3600), null, null))).code());
        verify(events, never()).save(any());
    }

    @Test
    void clublessEventIsRejectedEvenForAdmin() {
        assertEquals("EVENT_CLUB_REQUIRED", error(() -> svc.create(user, req(start, end, 50, null))).code());
        assertEquals("EVENT_CLUB_REQUIRED", error(() -> svc.create(new Actor(500L, true), req(start, end, null, null))).code());
        verify(events, never()).save(any());
    }

    @Test
    void plainMemberWithEventGrantCreatesPendingReviewEvent() {
        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(c);
        when(communities.roleOf(10L, 1L)).thenReturn(Optional.of(CommunityMember.Role.MEMBER));
        when(events.save(any())).thenAnswer(i -> i.getArgument(0));
        when(communities.namesById(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());

        EventView v = svc.create(user, req(start, end, null, 10L));

        assertEquals(UserEvent.Status.PENDING_REVIEW, v.status());
    }

    @Test
    void systemAdminCreatesActiveClubEvent() {
        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(c);
        when(events.save(any())).thenAnswer(i -> i.getArgument(0));
        when(communities.namesById(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());

        assertEquals(UserEvent.Status.ACTIVE, svc.create(new Actor(500L, true), req(start, end, null, 10L)).status());
    }

    @Test
    void communityEventRequiresModerator() {
        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(c);
        doThrow(new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "yetki yok"))
                .when(communities).require(eq(user), eq(10L), eq(ClubPermission.MANAGE_EVENTS));

        ApiException e = error(() -> svc.create(user, req(start, end, null, 10L)));

        assertEquals(HttpStatus.FORBIDDEN, e.status());
        verify(events, never()).save(any());
    }

    @Test
    void moderatorCreatesActiveCommunityEvent() {
        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(c);
        when(communities.roleOf(10L, 1L)).thenReturn(Optional.of(CommunityMember.Role.MODERATOR));
        when(events.save(any())).thenAnswer(i -> i.getArgument(0));
        when(communities.namesById(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());

        EventView v = svc.create(user, req(start, end, null, 10L));

        assertEquals(UserEvent.Status.ACTIVE, v.status());
        assertEquals(10L, v.communityId());
    }

    // ---- RSVP / kapasite ----

    @Test
    void goingFailsWith409WhenCapacityIsFull() {
        activeEvent(2, 2);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        when(events.tryIncrementGoing(5L)).thenReturn(0);

        ApiException e = error(() -> svc.rsvp(user, 5L, EventRsvp.Status.GOING));

        assertEquals("EVENT_FULL", e.code());
        assertEquals(HttpStatus.CONFLICT, e.status());
        verify(rsvps, never()).saveAndFlush(any());
    }

    @Test
    void goingReservesSeatAndSavesRsvp() {
        activeEvent(2, 1);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        when(events.tryIncrementGoing(5L)).thenReturn(1);
        when(events.goingCount(5L)).thenReturn(2);

        RsvpResult r = svc.rsvp(user, 5L, EventRsvp.Status.GOING);

        assertEquals(2, r.goingCount());
        assertEquals(EventRsvp.Status.GOING, r.myRsvp());
        verify(rsvps).saveAndFlush(any());
    }

    @Test
    void interestedDoesNotConsumeCapacity() {
        activeEvent(1, 1);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        when(events.goingCount(5L)).thenReturn(1);

        svc.rsvp(user, 5L, EventRsvp.Status.INTERESTED);

        verify(events, never()).tryIncrementGoing(anyLong());
    }

    @Test
    void switchingFromInterestedToGoingChecksCapacity() {
        activeEvent(1, 1);
        EventRsvp existing = new EventRsvp(5L, 1L, EventRsvp.Status.INTERESTED);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(existing));
        when(events.tryIncrementGoing(5L)).thenReturn(0);

        assertEquals("EVENT_FULL", error(() -> svc.rsvp(user, 5L, EventRsvp.Status.GOING)).code());
        assertEquals(EventRsvp.Status.INTERESTED, existing.getStatus());
    }

    @Test
    void switchingFromGoingFreesSeat() {
        activeEvent(1, 1);
        EventRsvp existing = new EventRsvp(5L, 1L, EventRsvp.Status.GOING);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(existing));

        svc.rsvp(user, 5L, EventRsvp.Status.INTERESTED);

        verify(events).decrementGoing(5L);
        assertEquals(EventRsvp.Status.INTERESTED, existing.getStatus());
    }

    @Test
    void repeatingSameRsvpIsIdempotent() {
        activeEvent(1, 1);
        when(rsvps.findByEventIdAndUserId(5L, 1L))
                .thenReturn(Optional.of(new EventRsvp(5L, 1L, EventRsvp.Status.GOING)));

        svc.rsvp(user, 5L, EventRsvp.Status.GOING);

        verify(events, never()).tryIncrementGoing(anyLong());
        verify(events, never()).decrementGoing(anyLong());
    }

    @Test
    void concurrentDuplicateRsvpBecomesConflict() {
        activeEvent(null, 0);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        when(events.tryIncrementGoing(5L)).thenReturn(1);
        when(rsvps.saveAndFlush(any())).thenThrow(new DataIntegrityViolationException("dup"));

        assertEquals("RSVP_CONFLICT", error(() -> svc.rsvp(user, 5L, EventRsvp.Status.GOING)).code());
    }

    @Test
    void cannotRsvpToEndedEvent() {
        UserEvent e = activeEvent(null, 0);
        e.setStartsAt(Instant.now().minus(Duration.ofHours(5)));
        e.setEndsAt(Instant.now().minus(Duration.ofHours(3)));

        assertEquals("EVENT_ENDED", error(() -> svc.rsvp(user, 5L, EventRsvp.Status.GOING)).code());
    }

    @Test
    void cannotRsvpToUnapprovedEvent() {
        UserEvent e = activeEvent(null, 0);
        e.setStatus(UserEvent.Status.PENDING_REVIEW);
        e.setCreatedBy(1L); // olusturan gorebilir ama RSVP yapamaz

        assertEquals("EVENT_NOT_OPEN", error(() -> svc.rsvp(user, 5L, EventRsvp.Status.GOING)).code());
    }

    // ---- yetki / guncelleme ----

    @Test
    void strangerCannotUpdateOrDelete() {
        activeEvent(null, 0);

        assertEquals(HttpStatus.FORBIDDEN,
                error(() -> svc.update(user, 5L, new UpdateEventRequest("Yeni baslik", null, null, null, null, null, null))).status());
        assertEquals(HttpStatus.FORBIDDEN, error(() -> svc.delete(user, 5L)).status());
    }

    @Test
    void capacityCannotDropBelowGoingCount() {
        UserEvent e = activeEvent(10, 6);
        e.setCreatedBy(1L);

        ApiException ex = error(() -> svc.update(user, 5L, new UpdateEventRequest(null, null, null, null, null, 5, null)));

        assertEquals("CAPACITY_TOO_LOW", ex.code());
    }

    @Test
    void communityModeratorCanManage() {
        UserEvent e = activeEvent(null, 0);
        e.setCommunityId(10L);
        when(communities.can(user, 10L, ClubPermission.MANAGE_EVENTS)).thenReturn(true);
        when(communities.can(new Actor(2L, false), 10L, ClubPermission.MANAGE_EVENTS)).thenReturn(false);

        org.junit.jupiter.api.Assertions.assertTrue(svc.canManage(user, e));
        org.junit.jupiter.api.Assertions.assertFalse(svc.canManage(new Actor(2L, false), e));
        org.junit.jupiter.api.Assertions.assertTrue(svc.canManage(new Actor(3L, true), e));
    }

    @Test
    void deleteCancelsEventForCreator() {
        UserEvent e = activeEvent(null, 0);
        e.setCreatedBy(1L);

        svc.delete(user, 5L);

        assertEquals(UserEvent.Status.CANCELLED, e.getStatus());
    }

    // ---- herkes olusturur / joinPolicy / istek akisi ----

    private edu.bingol.backend.event.admission.EventAdmissionHooks hooks() {
        edu.bingol.backend.event.admission.EventAdmissionHooks h =
                mock(edu.bingol.backend.event.admission.EventAdmissionHooks.class);
        when(h.joinPolicies(any())).thenReturn(Map.of());
        when(h.pendingCounts(any())).thenReturn(Map.of());
        when(h.requestStates(any(), any())).thenReturn(Map.of());
        svc.setAdmission(h);
        return h;
    }

    private void stubViews() {
        when(events.save(any())).thenAnswer(i -> i.getArgument(0));
        when(communities.namesById(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());
    }

    @Test
    void createWithApprovalPolicyStoresIt() {
        var h = hooks();
        when(h.requireApproval()).thenReturn(false);
        stubViews();
        var policy = edu.bingol.backend.event.admission.EventAdmission.Mode.APPROVAL;

        Community c = new Community();
        c.setId(10L);
        c.setStatus(Community.Status.ACTIVE);
        when(communities.load(10L)).thenReturn(c);
        when(communities.roleOf(10L, 1L)).thenReturn(Optional.of(CommunityMember.Role.ADMIN));

        svc.create(user, new CreateEventRequest("Hali saha", null, start, end, "Saha", 14, 10L, policy));

        verify(h).applyJoinPolicy(any(), org.mockito.ArgumentMatchers.eq(policy));
    }

    @Test
    void goingInApprovalEventBecomesPendingWithoutTakingASeat() {
        var h = hooks();
        activeEvent(1, 0);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.empty());
        when(h.requestIfApprovalRequired(any(), any())).thenReturn(true);

        var res = svc.rsvp(user, 5L, EventRsvp.Status.GOING);

        assertEquals(EventRsvp.Status.PENDING, res.myRsvp());
        verify(events, never()).tryIncrementGoing(anyLong());
        verify(rsvps, never()).saveAndFlush(any());
    }

    @Test
    void persistedStatusCannotBePendingOrRejected() {
        activeEvent(null, 0);
        assertEquals("VALIDATION_ERROR", error(() -> svc.rsvp(user, 5L, EventRsvp.Status.PENDING)).code());
        assertEquals("VALIDATION_ERROR", error(() -> svc.rsvp(user, 5L, EventRsvp.Status.REJECTED)).code());
    }

    @Test
    void viewShowsDerivedPendingRsvpAndPendingCountOnlyToManager() {
        var h = hooks();
        UserEvent e = activeEvent(10, 0);
        e.setCreatedBy(1L);
        when(h.requestStates(any(), any())).thenReturn(Map.of(5L, EventRsvp.Status.PENDING));
        when(h.pendingCounts(any())).thenReturn(Map.of(5L, 3L));
        when(communities.namesById(any())).thenReturn(Map.of());
        when(communities.usersById(any())).thenReturn(Map.of());

        EventView mine = svc.get(user, 5L);
        assertEquals(Long.valueOf(3L), mine.pendingCount());
        assertEquals(EventRsvp.Status.PENDING, mine.myRsvp());

        e.setCreatedBy(99L);
        EventView other = svc.get(new Actor(2L, false), 5L);
        assertEquals(null, other.pendingCount());
    }

    @Test
    void goingToInterestedLeavesTheChatRoom() {
        activeEvent(null, 1);
        EventRsvp existing = new EventRsvp(5L, 1L, EventRsvp.Status.GOING);
        when(rsvps.findByEventIdAndUserId(5L, 1L)).thenReturn(Optional.of(existing));
        var chat = mock(edu.bingol.backend.event.chat.EventChatHooks.class);
        svc.setChat(chat);

        svc.rsvp(user, 5L, EventRsvp.Status.INTERESTED);

        verify(chat).onLeft(5L, 1L);
    }
}
