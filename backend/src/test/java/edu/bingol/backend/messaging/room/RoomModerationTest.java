package edu.bingol.backend.messaging.room;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class RoomModerationTest {

    private final ChatRoomLinkRepository links = mock(ChatRoomLinkRepository.class);

    private static RoomModerationAuthorizer authorizer(RoomKind kind, boolean allow) {
        RoomModerationAuthorizer a = mock(RoomModerationAuthorizer.class);
        when(a.kind()).thenReturn(kind);
        when(a.canModerate(5L, 1L)).thenReturn(allow);
        return a;
    }

    private static ChatRoomLink link(RoomKind kind) {
        ChatRoomLink l = new ChatRoomLink();
        l.setKind(kind);
        l.setRefId(5L);
        l.setConversationId(10L);
        return l;
    }

    @Test
    void usesAuthorizerOfTheRoomKind() {
        RoomModeration m = new RoomModeration(links,
                List.of(authorizer(RoomKind.COMMUNITY, false), authorizer(RoomKind.EVENT, true)));
        when(links.findByConversationId(10L)).thenReturn(Optional.of(link(RoomKind.EVENT)));

        assertTrue(m.canModerate(10L, 1L));
    }

    @Test
    void otherKindAuthorizerDoesNotGrantPermission() {
        RoomModeration m = new RoomModeration(links, List.of(authorizer(RoomKind.COMMUNITY, true)));
        when(links.findByConversationId(10L)).thenReturn(Optional.of(link(RoomKind.EVENT)));

        assertFalse(m.canModerate(10L, 1L));
    }

    @Test
    void plainConversationIsNotModerated() {
        RoomModeration m = new RoomModeration(links, List.of(authorizer(RoomKind.COMMUNITY, true)));
        when(links.findByConversationId(11L)).thenReturn(Optional.empty());

        assertFalse(m.canModerate(11L, 1L));
    }
}
