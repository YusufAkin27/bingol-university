package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationView;
import edu.bingol.backend.messaging.room.ChatRoomLink;
import edu.bingol.backend.messaging.room.ChatRoomLinkRepository;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;

/** Oda avatari: etkinlik odasi yoneticinin kapagini, kulup odasi logoyu alir; yoksa null (istemci yedegi). */
class RoomAvatarCoverTest {

    private final ConversationRepository convs = mock(ConversationRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final ChatRoomLinkRepository links = mock(ChatRoomLinkRepository.class);
    private final UserEventRepository events = mock(UserEventRepository.class);
    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final ConversationService service = new ConversationService(convs, members,
            mock(MessageRepository.class), users, blocks, mock(MessageCodec.class));

    private ConversationView view(long cid, RoomKind kind, long ref, String own) {
        Conversation g = MessagingPrivacyW1dTest.conv(cid, Conversation.Type.GROUP);
        g.setAvatarUrl(own);
        when(convs.findById(cid)).thenReturn(Optional.of(g));
        ConversationMember m = ConversationMember.of(cid, 1L, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(cid, 1L)).thenReturn(Optional.of(m));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(cid)).thenReturn(List.of(m));
        when(members.findByConversationIdInAndLeftAtIsNull(any())).thenReturn(List.of(m));
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(users.findAllById(anyCollection())).thenReturn(List.of());
        ChatRoomLink l = new ChatRoomLink();
        l.setConversationId(cid);
        l.setKind(kind);
        l.setRefId(ref);
        when(links.findByConversationIdIn(any())).thenReturn(List.of(l));
        service.setRoomLinks(links);
        service.setRoomSources(events, communities);
        return service.detail(1L, cid).conversation();
    }

    @Test
    void eventRoomUsesCoverAndFallsBackToNull() {
        UserEvent e = new UserEvent();
        e.setId(7L);
        e.setCoverUrl("/files/cover.jpg");
        when(events.findAllById(any())).thenReturn(List.of(e));
        assertEquals("/files/cover.jpg", view(10L, RoomKind.EVENT, 7L, null).avatarUrl());
        e.setCoverUrl(null);
        assertNull(view(11L, RoomKind.EVENT, 7L, null).avatarUrl());
    }

    @Test
    void clubRoomUsesLogoAndOwnAvatarWins() {
        Community c = new Community();
        c.setId(3L);
        c.setLogoUrl("/files/logo.png");
        when(communities.findAllById(any())).thenReturn(List.of(c));
        assertEquals("/files/logo.png", view(12L, RoomKind.COMMUNITY, 3L, null).avatarUrl());
        assertEquals("/files/own.png", view(13L, RoomKind.COMMUNITY, 3L, "/files/own.png").avatarUrl());
    }
}
