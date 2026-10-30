package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationDetail;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Golge engel: sohbet gorunumlerinde avatar gizleme ve goruntuleyene gore son mesaj anahtari. */
class ConversationShadowTest {

    final ConversationRepository convs = mock(ConversationRepository.class);
    final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    final MessageRepository messages = mock(MessageRepository.class);
    final UserRepository users = mock(UserRepository.class);
    final BlockService blocks = mock(BlockService.class);
    final ConversationService service = new ConversationService(convs, members, messages, users, blocks,
            mock(MessageCodec.class));

    Conversation conv;
    ConversationMember me;
    ConversationMember other;

    static User user(long id) {
        User u = new User();
        u.setId(id);
        u.setDisplayName("U" + id);
        u.setAvatarUrl("/files/avatars/a" + id + ".jpg");
        return u;
    }

    @BeforeEach
    void setUp() {
        conv = new Conversation();
        conv.setId(5L);
        conv.setType(Conversation.Type.DIRECT);
        conv.setCreatedBy(1L);
        me = ConversationMember.of(5L, 1L, ConversationMember.Role.MEMBER);
        other = ConversationMember.of(5L, 2L, ConversationMember.Role.MEMBER);
        when(convs.findById(5L)).thenReturn(Optional.of(conv));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 1L)).thenReturn(Optional.of(me));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(5L)).thenReturn(List.of(me, other));
        when(members.findByConversationIdInAndLeftAtIsNull(org.mockito.ArgumentMatchers.any()))
                .thenReturn(List.of(me, other));
        when(users.findAllById(org.mockito.ArgumentMatchers.any())).thenReturn(List.of(user(1L), user(2L)));
    }

    @Test
    void blockedPeerAvatarIsNullInDetailMembersAndPeer() {
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of(2L));

        ConversationDetail d = service.detail(1L, 5L);

        assertNull(d.conversation().peer().avatarUrl());
        assertEquals("U2", d.conversation().peer().displayName()); // ad kalir
        assertNull(d.members().stream().filter(m -> m.userId() == 2L).findFirst().orElseThrow().avatarUrl());
        assertNotNull(d.members().stream().filter(m -> m.userId() == 1L).findFirst().orElseThrow().avatarUrl());
    }

    @Test
    void directPeerOnlineFlagComesFromBulkPresenceAndIsHiddenWhenBlocked() {
        edu.bingol.backend.messaging.ws.PresenceService presence = mock(edu.bingol.backend.messaging.ws.PresenceService.class);
        service.setPresence(presence);
        when(presence.onlineAmong(org.mockito.ArgumentMatchers.anyCollection())).thenReturn(Set.of(2L));
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());

        assertEquals(Boolean.TRUE, service.detail(1L, 5L).conversation().peer().online());

        when(presence.onlineAmong(org.mockito.ArgumentMatchers.anyCollection())).thenReturn(Set.of());
        assertEquals(Boolean.FALSE, service.detail(1L, 5L).conversation().peer().online());

        when(presence.onlineAmong(org.mockito.ArgumentMatchers.anyCollection())).thenReturn(Set.of(2L));
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of(2L));
        assertNull(service.detail(1L, 5L).conversation().peer().online()); // engelli: durum sizmaz
    }

    @Test
    void groupLastMessageCarriesSenderNameButDirectDoesNot() {
        Message m = new Message();
        m.setId(90L);
        m.setConversationId(5L);
        m.setSenderId(2L);
        m.setBody("Toplanti 5te");
        m.setCreatedAt(java.time.Instant.now());
        conv.setLastMessageId(90L);
        when(messages.findAllById(org.mockito.ArgumentMatchers.any())).thenReturn(List.of(m));
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());

        assertNull(service.detail(1L, 5L).conversation().lastMessage().senderName()); // birebir: onek yok

        conv.setType(Conversation.Type.GROUP);
        assertEquals("U2", service.detail(1L, 5L).conversation().lastMessage().senderName());
    }

    @Test
    void unblockedPeerKeepsAvatar() {
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());

        assertNotNull(service.detail(1L, 5L).conversation().peer().avatarUrl());
    }

    @Test
    void lastKeyHidesSuppressedMessagesFromRecipientButNotSender() {
        conv.setLastMessageId(90L);
        assertEquals(90L, ConversationService.lastKey(conv, List.of(me, other), 2L)); // golge yok: lastMessageId

        conv.setShadowed(true);
        conv.setLastVisibleMessageId(60L); // 61..90 arasi bastirilmis (gonderen: 1)
        me.setLastOwnSuppressedMessageId(90L);
        assertEquals(90L, ConversationService.lastKey(conv, List.of(me, other), 1L)); // gonderen kendi mesajini gorur
        assertEquals(60L, ConversationService.lastKey(conv, List.of(me, other), 2L)); // alici yalniz gorunur olani

        conv.setLastVisibleMessageId(null); // alicinin hic gorunur mesaji yok: konusma listede yok
        assertNull(ConversationService.lastKey(conv, List.of(me, other), 2L));
    }
}
