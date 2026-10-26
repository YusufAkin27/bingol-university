package edu.bingol.backend.event;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.ClubMemberLeftEvent;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomKind;
import java.util.List;
import org.junit.jupiter.api.Test;

class EventRoomClubListenerTest {

    private final UserEventRepository events = mock(UserEventRepository.class);
    private final RoomConversations rooms = mock(RoomConversations.class);
    private final EventRoomClubListener listener = new EventRoomClubListener(events, rooms);

    @Test
    void removesLeavingMemberFromClubEventRooms() {
        when(events.idsByCommunityExcludingCreator(10L, 7L)).thenReturn(List.of(100L, 101L));

        listener.onMemberLeft(new ClubMemberLeftEvent(10L, 7L));

        verify(rooms).removeMember(RoomKind.EVENT, 100L, 7L);
        verify(rooms).removeMember(RoomKind.EVENT, 101L, 7L);
    }

    @Test
    void roomFailureDoesNotLeak() {
        when(events.idsByCommunityExcludingCreator(10L, 7L)).thenReturn(List.of(100L));
        when(rooms.removeMember(RoomKind.EVENT, 100L, 7L)).thenThrow(new IllegalStateException("db"));

        listener.onMemberLeft(new ClubMemberLeftEvent(10L, 7L));

        verify(rooms, never()).removeMember(RoomKind.COMMUNITY, 10L, 7L);
    }
}
