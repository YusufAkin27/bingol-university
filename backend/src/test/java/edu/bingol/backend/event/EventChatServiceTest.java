package edu.bingol.backend.event;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Actor;
import edu.bingol.backend.messaging.ConversationService;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** GET /api/events/{id}/chat: RSVP ya da organizator yetkisi, iptal edilmis etkinlik, kapali oda. */
class EventChatServiceTest {

    private final EventService events = mock(EventService.class);
    private final EventRsvpRepository rsvps = mock(EventRsvpRepository.class);
    private final RoomConversations rooms = mock(RoomConversations.class);
    private final ConversationService convs = mock(ConversationService.class);
    private final EventChatService chat = new EventChatService(events, rsvps, rooms, convs);
    private final Actor user = new Actor(3L, false);
    private final UserEvent ev = new UserEvent();
    private final ConversationView view = mock(ConversationView.class);

    EventChatServiceTest() {
        ev.setId(5L);
        ev.setTitle("Konferans");
        ev.setCreatedBy(99L);
        ev.setStatus(UserEvent.Status.ACTIVE);
        when(events.loadVisible(user, 5L)).thenReturn(ev);
        when(rooms.find(RoomKind.EVENT, 5L)).thenReturn(Optional.of(new RoomInfo(40L, RoomKind.EVENT, 5L, false)));
        when(rooms.addMember(RoomKind.EVENT, 5L, 3L)).thenReturn(true);
        when(convs.view(3L, 40L)).thenReturn(view);
    }

    @Test
    void rsvpHolderEntersRoom() {
        when(rsvps.findByEventIdAndUserId(5L, 3L)).thenReturn(Optional.of(new EventRsvp(5L, 3L, EventRsvp.Status.INTERESTED)));
        assertSame(view, chat.open(user, 5L));
        verify(rooms).ensureRoom(RoomKind.EVENT, 5L, "Konferans", 99L);
    }

    @Test
    void managerWithoutRsvpEntersRoom() {
        when(events.canManage(user, ev)).thenReturn(true);
        assertSame(view, chat.open(user, 5L));
    }

    @Test
    void visitorWithoutRsvpGets403() {
        ApiException e = assertThrows(ApiException.class, () -> chat.open(user, 5L));
        assertEquals(HttpStatus.FORBIDDEN, e.status());
        verify(rooms, never()).ensureRoom(RoomKind.EVENT, 5L, "Konferans", 99L);
        verify(rooms, never()).addMember(RoomKind.EVENT, 5L, 3L);
    }

    @Test
    void cancelledEventGets404() {
        ev.setStatus(UserEvent.Status.CANCELLED);
        when(events.canManage(user, ev)).thenReturn(true);
        assertEquals(HttpStatus.NOT_FOUND, assertThrows(ApiException.class, () -> chat.open(user, 5L)).status());
    }

    @Test
    void closedRoomGets409() {
        when(events.canManage(user, ev)).thenReturn(true);
        when(rooms.find(RoomKind.EVENT, 5L)).thenReturn(Optional.of(new RoomInfo(40L, RoomKind.EVENT, 5L, true)));
        assertEquals("CHAT_ROOM_CLOSED", assertThrows(ApiException.class, () -> chat.open(user, 5L)).code());
    }
}
