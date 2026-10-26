package edu.bingol.backend.event.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;

class CoOrganizerAndAnnouncementTest {

    private final EventService events = mock(EventService.class);
    private final CoOrganizerRepository coRepo = mock(CoOrganizerRepository.class);
    private final CommunityService communities = mock(CommunityService.class);
    private final BlockService blocks = mock(BlockService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final CoOrganizerService co = new CoOrganizerService(events, coRepo, communities, blocks, notifications);

    private static final Actor OWNER = new Actor(1L, false);
    private static final Actor OTHER = new Actor(2L, false);

    private UserEvent event() {
        UserEvent e = new UserEvent();
        e.setId(10L);
        e.setTitle("Etkinlik");
        e.setCreatedBy(1L);
        e.setStatus(UserEvent.Status.ACTIVE);
        e.setStartsAt(Instant.now().plusSeconds(3600));
        e.setEndsAt(Instant.now().plusSeconds(7200));
        return e;
    }

    private User user(long id, UserStatus st) {
        User u = new User();
        u.setId(id);
        u.setDisplayName("U" + id);
        u.setStatus(st);
        return u;
    }

    private void code(ApiException ex, HttpStatus s, String c) {
        assertEquals(s, ex.status());
        assertEquals(c, ex.code());
    }

    @Test
    void ownerAddsCoOrganizerAndTargetIsNotified() {
        when(events.load(10L)).thenReturn(event());
        when(communities.usersById(any())).thenReturn(Map.of(3L, user(3, UserStatus.ACTIVE)));
        when(coRepo.countByEventId(10L)).thenReturn(4L);
        co.add(OWNER, 10L, 3L);
        verify(coRepo).saveAndFlush(any(CoOrganizer.class));
        verify(notifications).sendTemplate(eq(3L), eq(ExtrasTemplates.CO_ORGANIZER_ADDED), any(), any(), eq("Etkinlik"));
    }

    @Test
    void sixthCoOrganizerRejected() {
        when(events.load(10L)).thenReturn(event());
        when(communities.usersById(any())).thenReturn(Map.of(3L, user(3, UserStatus.ACTIVE)));
        when(coRepo.countByEventId(10L)).thenReturn(5L);
        code(assertThrows(ApiException.class, () -> co.add(OWNER, 10L, 3L)), HttpStatus.CONFLICT, "CO_ORGANIZER_LIMIT");
        verify(coRepo, never()).saveAndFlush(any());
    }

    @Test
    void coOrganizerCannotAddOthers() {
        UserEvent e = event();
        when(events.load(10L)).thenReturn(e);
        // OTHER ortak organizator: requireManager gecer ama sahip degil -> 403
        when(events.requireManager(OTHER, e)).thenReturn(e);
        code(assertThrows(ApiException.class, () -> co.add(OTHER, 10L, 3L)), HttpStatus.FORBIDDEN, "FORBIDDEN");
        verify(coRepo, never()).saveAndFlush(any());
    }

    @Test
    void strangerGets404WhenEventInvisible() {
        UserEvent e = event();
        when(events.load(10L)).thenReturn(e);
        when(events.requireManager(OTHER, e)).thenThrow(new ApiException(HttpStatus.NOT_FOUND, "EVENT_NOT_FOUND", "x"));
        code(assertThrows(ApiException.class, () -> co.add(OTHER, 10L, 3L)), HttpStatus.NOT_FOUND, "EVENT_NOT_FOUND");
    }

    @Test
    void cannotAddCreatorSelfSuspendedOrBlocked() {
        when(events.load(10L)).thenReturn(event());
        code(assertThrows(ApiException.class, () -> co.add(OWNER, 10L, 1L)), HttpStatus.BAD_REQUEST, "CO_ORGANIZER_TARGET_INVALID");
        when(communities.usersById(any())).thenReturn(Map.of(3L, user(3, UserStatus.SUSPENDED)));
        code(assertThrows(ApiException.class, () -> co.add(OWNER, 10L, 3L)), HttpStatus.NOT_FOUND, "USER_NOT_FOUND");
        when(communities.usersById(any())).thenReturn(Map.of(4L, user(4, UserStatus.ACTIVE)));
        when(blocks.isBlocked(1L, 4L)).thenReturn(true);
        code(assertThrows(ApiException.class, () -> co.add(OWNER, 10L, 4L)), HttpStatus.NOT_FOUND, "USER_NOT_FOUND");
    }

    @Test
    void coOrganizerCanLeaveButNotRemoveOthers() {
        UserEvent e = event();
        when(events.load(10L)).thenReturn(e);
        CoOrganizer c = new CoOrganizer();
        when(coRepo.findByEventIdAndUserId(10L, 2L)).thenReturn(Optional.of(c));
        co.remove(OTHER, 10L, 2L);
        verify(coRepo).delete(c);
        when(events.requireManager(OTHER, e)).thenReturn(e);
        code(assertThrows(ApiException.class, () -> co.remove(OTHER, 10L, 3L)), HttpStatus.FORBIDDEN, "FORBIDDEN");
    }

    @Test
    void eventServiceTreatsCoOrganizerAsManager() {
        EventService real = new EventService(mock(edu.bingol.backend.event.UserEventRepository.class), rsvps,
                mock(edu.bingol.backend.event.OfficialEventRepository.class), communities, notifications,
                mock(edu.bingol.backend.common.storage.FileStorage.class));
        UserEvent e = event();
        assertEquals(false, real.canManage(OTHER, e));
        CoOrganizerLookup lookup = mock(CoOrganizerLookup.class);
        when(lookup.isCoOrganizer(10L, 2L)).thenReturn(true);
        real.setCoOrganizers(lookup);
        assertEquals(true, real.canManage(OTHER, e));
        assertEquals(false, real.canManage(new Actor(3L, false), e));
    }

    // ---- toplu duyuru ----

    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final EventAnnouncementRepository log = mock(EventAnnouncementRepository.class);
    private final AnnouncementService ann = new AnnouncementService(events, rsvps, log, communities, blocks, notifications);

    @Test
    void announcementGoesOnlyToActiveNonBlockedGoingUsersExceptSender() {
        UserEvent e = event();
        when(events.load(10L)).thenReturn(e);
        when(events.requireManager(OWNER, e)).thenReturn(e);
        when(log.countByEventIdAndCreatedAtGreaterThanEqual(anyLong(), any())).thenReturn(1L);
        when(rsvps.userIds(eq(10L), eq(EventRsvp.Status.GOING), any(Pageable.class))).thenReturn(List.of(1L, 2L, 3L, 4L, 5L));
        when(communities.usersById(any())).thenReturn(Map.of(
                1L, user(1, UserStatus.ACTIVE), 2L, user(2, UserStatus.ACTIVE), 3L, user(3, UserStatus.SUSPENDED),
                4L, user(4, UserStatus.ACTIVE)));
        when(blocks.isBlocked(1L, 4L)).thenReturn(true);
        var r = ann.send(OWNER, 10L, " Baslik ", " Mesaj ", Instant.now());
        assertEquals(1, r.recipients());
        assertEquals(1, r.remainingToday());
        verify(notifications, times(1)).sendTemplate(eq(2L), eq(ExtrasTemplates.ANNOUNCEMENT), any(), any(),
                eq("Etkinlik"), eq("Baslik"), eq("Mesaj"));
    }

    @Test
    void fourthAnnouncementOfTheDayRejected() {
        UserEvent e = event();
        when(events.load(10L)).thenReturn(e);
        when(events.requireManager(OWNER, e)).thenReturn(e);
        when(log.countByEventIdAndCreatedAtGreaterThanEqual(anyLong(), any())).thenReturn(3L);
        code(assertThrows(ApiException.class, () -> ann.send(OWNER, 10L, "a", "b", Instant.now())),
                HttpStatus.TOO_MANY_REQUESTS, "ANNOUNCEMENT_LIMIT");
        verify(log, never()).save(any());
    }

    @Test
    void announcementNeedsActiveUnfinishedEventAndManager() {
        UserEvent e = event();
        e.setStatus(UserEvent.Status.CANCELLED);
        when(events.load(10L)).thenReturn(e);
        when(events.requireManager(OTHER, e)).thenThrow(new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "x"));
        code(assertThrows(ApiException.class, () -> ann.send(OTHER, 10L, "a", "b", Instant.now())), HttpStatus.FORBIDDEN, "FORBIDDEN");
        when(events.requireManager(OWNER, e)).thenReturn(e);
        code(assertThrows(ApiException.class, () -> ann.send(OWNER, 10L, "a", "b", Instant.now())), HttpStatus.CONFLICT, "EVENT_NOT_OPEN");
    }
}
