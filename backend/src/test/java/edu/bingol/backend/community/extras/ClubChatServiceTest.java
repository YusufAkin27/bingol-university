package edu.bingol.backend.community.extras;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.Actor;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember.Role;
import edu.bingol.backend.messaging.ConversationService;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.messaging.room.RoomConversations;
import edu.bingol.backend.messaging.room.RoomConversations.RoomInfo;
import edu.bingol.backend.messaging.room.RoomKind;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** GET /api/communities/{id}/chat: uyelik yetkisi, kapali oda, odanin yoksa kurulmasi. */
class ClubChatServiceTest {

    private final ClubExtrasTestSupport t = new ClubExtrasTestSupport();
    private final RoomConversations rooms = mock(RoomConversations.class);
    private final ClubExtrasHooks hooks = mock(ClubExtrasHooks.class);
    private final ConversationService convs = mock(ConversationService.class);
    private final ClubChatService chat = new ClubChatService(t.communities, rooms, hooks, t.permissions, convs);
    private final Actor member = new Actor(3L, false);
    private final ConversationView view = mock(ConversationView.class);

    @Test
    void activeMemberGetsConversationAndIsAdded() {
        t.member(3L, Role.MEMBER);
        when(rooms.find(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.of(new RoomInfo(77L, RoomKind.COMMUNITY, 10L, false)));
        when(rooms.addMember(RoomKind.COMMUNITY, 10L, 3L)).thenReturn(true);
        when(convs.view(3L, 77L)).thenReturn(view);
        assertSame(view, chat.open(member, 10L));
        verify(hooks, never()).onCommunityActivated(t.club);
    }

    @Test
    void missingRoomIsCreated() {
        t.member(3L, Role.MEMBER);
        when(rooms.find(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.empty())
                .thenReturn(Optional.of(new RoomInfo(77L, RoomKind.COMMUNITY, 10L, false)));
        when(rooms.addMember(RoomKind.COMMUNITY, 10L, 3L)).thenReturn(true);
        when(convs.view(3L, 77L)).thenReturn(view);
        chat.open(member, 10L);
        verify(hooks).onCommunityActivated(t.club);
    }

    @Test
    void nonMemberGets404() {
        var e = ClubExtrasTestSupport.error(() -> chat.open(new Actor(8L, false), 10L));
        assertEquals(HttpStatus.NOT_FOUND, e.status());
        assertEquals("CHAT_ROOM_NOT_FOUND", e.code());
        verify(rooms, never()).addMember(RoomKind.COMMUNITY, 10L, 8L);
    }

    @Test
    void inactiveClubGets404() {
        t.member(3L, Role.MEMBER);
        t.club.setStatus(Community.Status.PENDING_REVIEW);
        assertEquals(HttpStatus.NOT_FOUND, ClubExtrasTestSupport.error(() -> chat.open(member, 10L)).status());
    }

    @Test
    void closedRoomGets409() {
        t.member(3L, Role.MEMBER);
        when(rooms.find(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.of(new RoomInfo(77L, RoomKind.COMMUNITY, 10L, true)));
        var e = ClubExtrasTestSupport.error(() -> chat.open(member, 10L));
        assertEquals("CHAT_ROOM_CLOSED", e.code());
        verify(convs, never()).view(anyLong(), anyLong());
    }
}
