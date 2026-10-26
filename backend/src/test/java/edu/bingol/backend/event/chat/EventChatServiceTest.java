package edu.bingol.backend.event.chat;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.CommunityService;
import edu.bingol.backend.event.EventRsvp;
import edu.bingol.backend.event.EventRsvpRepository;
import edu.bingol.backend.event.EventService;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.event.chat.EventChatService.EventChatView;
import edu.bingol.backend.event.extras.CoOrganizerRepository;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class EventChatServiceTest {

    private final EventService events = mock(EventService.class);
    private final RoomConversations rooms = mock(RoomConversations.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final UserEventRepository eventRepo = mock(UserEventRepository.class);
    private final CoOrganizerRepository coOrgs = mock(CoOrganizerRepository.class);
    private final CommunityService communities = mock(CommunityService.class);

    private final Actor organizer = new Actor(10L, false);
    private final Actor guest = new Actor(20L, false);

    private EventChatService svc(boolean auto) {
        return new EventChatService(events, rooms, rsvps, eventRepo, coOrgs, communities, auto, 7);
    }

    private UserEvent event(UserEvent.Status st, Instant ends) {
        UserEvent e = new UserEvent();
        e.setId(5L);
        e.setTitle("Konferans");
        e.setCreatedBy(10L);
        e.setStatus(st);
        e.setStartsAt(ends.minus(Duration.ofHours(2)));
        e.setEndsAt(ends);
        when(events.load(5L)).thenReturn(e);
        when(events.loadVisible(any(), eq(5L))).thenReturn(e);
        when(events.requireManager(organizer, e)).thenReturn(e);
        when(events.canManage(organizer, e)).thenReturn(true);
        when(eventRepo.findById(5L)).thenReturn(Optional.of(e));
        return e;
    }

    private UserEvent activeEvent() {
        return event(UserEvent.Status.ACTIVE, Instant.now().plus(Duration.ofDays(1)));
    }

    private void openRoom() {
        when(rooms.find(RoomKind.EVENT, 5L)).thenReturn(Optional.of(new RoomInfo(77L, RoomKind.EVENT, 5L, false)));
    }

    @Test
    void organizerOpensRoomAndGoingAreAdded() {
        activeEvent();
        EventRsvp r = new EventRsvp(5L, 30L, EventRsvp.Status.GOING);
        when(rsvps.findByEventIdAndStatus(5L, EventRsvp.Status.GOING)).thenReturn(List.of(r));
        when(rooms.find(RoomKind.EVENT, 5L)).thenReturn(Optional.empty(),
                Optional.of(new RoomInfo(77L, RoomKind.EVENT, 5L, false)));
        EventChatView v = svc(false).open(organizer, 5L);
        verify(rooms).ensureRoom(RoomKind.EVENT, 5L, "Konferans", 10L);
        verify(rooms).addMembers(RoomKind.EVENT, 5L, List.of(10L, 30L));
        verify(rooms).addMembers(RoomKind.EVENT, 5L, List.of(10L));
        assertEquals(77L, v.conversationId());
    }

    @Test
    void nonOrganizerCannotOpen() {
        UserEvent e = activeEvent();
        when(events.requireManager(guest, e)).thenThrow(new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "x"));
        assertEquals("FORBIDDEN", assertThrows(ApiException.class, () -> svc(false).open(guest, 5L)).code());
        verify(rooms, never()).ensureRoom(any(), any(), any(), any());
    }

    @Test
    void cannotOpenForCancelledOrLongEndedEvent() {
        event(UserEvent.Status.CANCELLED, Instant.now().plus(Duration.ofDays(1)));
        assertEquals("EVENT_NOT_OPEN", assertThrows(ApiException.class, () -> svc(false).open(organizer, 5L)).code());
        event(UserEvent.Status.ACTIVE, Instant.now().minus(Duration.ofDays(8)));
        assertEquals("EVENT_CHAT_ENDED", assertThrows(ApiException.class, () -> svc(false).open(organizer, 5L)).code());
    }

    @Test
    void getIs404ForNonMemberAndNoRoom() {
        activeEvent();
        assertEquals("CHAT_ROOM_NOT_FOUND", assertThrows(ApiException.class, () -> svc(false).get(guest, 5L)).code());
        openRoom();
        when(rooms.isMember(RoomKind.EVENT, 5L, 20L)).thenReturn(false);
        ApiException ex = assertThrows(ApiException.class, () -> svc(false).get(guest, 5L));
        assertEquals(HttpStatus.NOT_FOUND, ex.status());
    }

    @Test
    void memberSeesRoom() {
        activeEvent();
        openRoom();
        when(rooms.isMember(RoomKind.EVENT, 5L, 20L)).thenReturn(true);
        when(rooms.memberCount(RoomKind.EVENT, 5L)).thenReturn(3L);
        EventChatView v = svc(false).get(guest, 5L);
        assertTrue(v.joined());
        assertEquals(3L, v.memberCount());
        assertEquals(77L, v.conversationId());
    }

    @Test
    void joinRequiresGoingAndOpenRoom() {
        activeEvent();
        openRoom();
        assertEquals("CHAT_ROOM_NOT_FOUND", assertThrows(ApiException.class, () -> svc(false).join(guest, 5L)).code());
        when(rsvps.findByEventIdAndUserId(5L, 20L))
                .thenReturn(Optional.of(new EventRsvp(5L, 20L, EventRsvp.Status.INTERESTED)));
        assertEquals("CHAT_ROOM_NOT_FOUND", assertThrows(ApiException.class, () -> svc(false).join(guest, 5L)).code());
        when(rsvps.findByEventIdAndUserId(5L, 20L))
                .thenReturn(Optional.of(new EventRsvp(5L, 20L, EventRsvp.Status.GOING)));
        when(rooms.addMember(RoomKind.EVENT, 5L, 20L)).thenReturn(true);
        svc(false).join(guest, 5L);
        verify(rooms).addMember(RoomKind.EVENT, 5L, 20L);
    }

    @Test
    void joinClosedRoomConflicts() {
        activeEvent();
        when(rooms.find(RoomKind.EVENT, 5L)).thenReturn(Optional.of(new RoomInfo(77L, RoomKind.EVENT, 5L, true)));
        when(rsvps.findByEventIdAndUserId(5L, 20L))
                .thenReturn(Optional.of(new EventRsvp(5L, 20L, EventRsvp.Status.GOING)));
        assertEquals("CHAT_ROOM_CLOSED", assertThrows(ApiException.class, () -> svc(false).join(guest, 5L)).code());
    }

    @Test
    void organizerClosesRoom() {
        activeEvent();
        openRoom();
        svc(false).setClosed(organizer, 5L, true);
        verify(rooms).closeRoom(RoomKind.EVENT, 5L);
    }

    @Test
    void hooksDoNothingWithoutRoomWhenAutoOff() {
        activeEvent();
        when(rooms.find(RoomKind.EVENT, 5L)).thenReturn(Optional.empty());
        svc(false).onGoing(5L, 20L);
        verify(rooms, never()).ensureRoom(any(), any(), any(), any());
        verify(rooms, never()).addMembers(any(), any(), anyCollection());
    }

    @Test
    void autoModeCreatesRoomOnFirstGoing() {
        activeEvent();
        when(rooms.find(RoomKind.EVENT, 5L)).thenReturn(Optional.empty());
        svc(true).onGoing(5L, 20L);
        verify(rooms).ensureRoom(RoomKind.EVENT, 5L, "Konferans", 10L);
        verify(rooms).addMembers(RoomKind.EVENT, 5L, List.of(20L));
    }

    @Test
    void goingJoinsAndLeavingRemoves() {
        activeEvent();
        openRoom();
        svc(false).onGoing(5L, 20L);
        verify(rooms).addMembers(RoomKind.EVENT, 5L, List.of(20L));
        svc(false).onLeft(5L, 20L);
        verify(rooms).removeMember(RoomKind.EVENT, 5L, 20L);
    }

    @Test
    void organizersStayInRoomOnLeave() {
        activeEvent();
        openRoom();
        svc(false).onLeft(5L, 10L); // olusturan
        when(coOrgs.existsByEventIdAndUserId(5L, 40L)).thenReturn(true);
        svc(false).onLeft(5L, 40L); // ortak organizator
        verify(rooms, never()).removeMember(any(), any(), any());
    }

    @Test
    void cancelClosesRoomAndHooksNeverThrow() {
        when(rooms.find(RoomKind.EVENT, 5L)).thenThrow(new IllegalStateException("db"));
        svc(false).onGoing(5L, 20L);
        svc(false).onLeft(5L, 20L);
        org.mockito.Mockito.doThrow(new IllegalStateException("db")).when(rooms).closeRoom(RoomKind.EVENT, 5L);
        svc(false).onCancelled(5L);
        assertFalse(false);
        org.mockito.Mockito.doNothing().when(rooms).closeRoom(RoomKind.EVENT, 6L);
        svc(false).onCancelled(6L);
        verify(rooms).closeRoom(RoomKind.EVENT, 6L);
    }
}
