package edu.bingol.backend.messaging.room;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.Conversation;
import edu.bingol.backend.messaging.ConversationMember;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.ConversationRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** Genel sohbet odasi altyapisi: kurulum, uyelik kurallari, sinir, kapatma/acma. */
class RoomConversationsTest {

    private final ChatRoomLinkRepository links = mock(ChatRoomLinkRepository.class);
    private final ConversationRepository convs = mock(ConversationRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final RoomConversations rooms = new RoomConversations(links, convs, members, users, 3);

    private static ChatRoomLink link(boolean closed) {
        ChatRoomLink l = new ChatRoomLink();
        l.setId(1L);
        l.setKind(RoomKind.COMMUNITY);
        l.setRefId(10L);
        l.setConversationId(500L);
        l.setClosed(closed);
        return l;
    }

    private void userOk(long id) {
        User u = new User();
        u.setId(id);
        u.setEmailVerified(true);
        when(users.findById(id)).thenReturn(Optional.of(u));
    }

    private void openRoom() {
        when(links.findByKindAndRefId(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.of(link(false)));
        Conversation c = new Conversation();
        c.setId(500L);
        c.setLastMessageId(77L);
        when(convs.findById(500L)).thenReturn(Optional.of(c));
    }

    @Test
    void ensureRoomCreatesGroupConversationWithoutAdminAndLinksIt() {
        userOk(1L);
        when(links.findByKindAndRefId(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.empty());
        when(convs.save(any())).thenAnswer(i -> {
            Conversation c = i.getArgument(0);
            c.setId(500L);
            return c;
        });
        when(links.insertIfAbsent(eq("COMMUNITY"), eq(10L), eq(500L), any())).thenReturn(1);

        Long id = rooms.ensureRoom(RoomKind.COMMUNITY, 10L, "Yazilim Kulubu", 1L);

        assertEquals(500L, id);
        ArgumentCaptor<Conversation> cc = ArgumentCaptor.forClass(Conversation.class);
        verify(convs).save(cc.capture());
        assertEquals(Conversation.Type.GROUP, cc.getValue().getType());
        assertEquals("Yazilim Kulubu", cc.getValue().getTitle());
        // Odada kimse grup yoneticisi olmaz: elle uye ekleme/cikarma uclari calismaz, uyelik kaynaktan senkronlanir.
        verify(members).save(org.mockito.ArgumentMatchers.argThat(m ->
                m.getUserId().equals(1L) && m.getRole() == ConversationMember.Role.MEMBER));
    }

    @Test
    void ensureRoomIsIdempotent() {
        when(links.findByKindAndRefId(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.of(link(false)));

        assertEquals(500L, rooms.ensureRoom(RoomKind.COMMUNITY, 10L, "x", 1L));

        verify(convs, never()).save(any());
    }

    @Test
    void ensureRoomRaceDiscardsOwnConversationAndReturnsWinner() {
        when(links.findByKindAndRefId(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.empty())
                .thenReturn(Optional.of(link(false)));
        when(convs.save(any())).thenAnswer(i -> {
            Conversation c = i.getArgument(0);
            c.setId(900L);
            return c;
        });
        when(links.insertIfAbsent(anyString(), anyLong(), anyLong(), any())).thenReturn(0);

        assertEquals(500L, rooms.ensureRoom(RoomKind.COMMUNITY, 10L, "x", 1L));

        verify(convs).deleteById(900L);
        verify(members, never()).save(any());
    }

    @Test
    void longTitleIsCutTo100() {
        when(links.findByKindAndRefId(any(), anyLong())).thenReturn(Optional.empty());
        when(convs.save(any())).thenAnswer(i -> {
            Conversation c = i.getArgument(0);
            c.setId(500L);
            return c;
        });
        when(links.insertIfAbsent(anyString(), anyLong(), anyLong(), any())).thenReturn(1);
        when(users.findById(anyLong())).thenReturn(Optional.empty());

        rooms.ensureRoom(RoomKind.EVENT, 5L, "x".repeat(150), 1L);

        verify(convs).save(org.mockito.ArgumentMatchers.argThat(c -> c.getTitle().length() == 100));
    }

    @Test
    void addMemberAddsNewUserWithReadCursorAtLastMessage() {
        openRoom();
        userOk(7L);
        when(members.findByConversationIdAndUserId(500L, 7L)).thenReturn(Optional.empty());

        assertTrue(rooms.addMember(RoomKind.COMMUNITY, 10L, 7L));

        ArgumentCaptor<ConversationMember> cc = ArgumentCaptor.forClass(ConversationMember.class);
        verify(members).save(cc.capture());
        assertEquals(77L, cc.getValue().getLastReadMessageId()); // gecmis mesajlar okunmamis sayilmaz
    }

    @Test
    void addMemberRejoinResetsLeftAtAndHistory() {
        openRoom();
        userOk(7L);
        ConversationMember old = ConversationMember.of(500L, 7L, ConversationMember.Role.ADMIN);
        old.setLeftAt(Instant.now().minusSeconds(60));
        when(members.findByConversationIdAndUserId(500L, 7L)).thenReturn(Optional.of(old));

        assertTrue(rooms.addMember(RoomKind.COMMUNITY, 10L, 7L));

        assertNull(old.getLeftAt());
        assertEquals(ConversationMember.Role.MEMBER, old.getRole());
        assertEquals(77L, old.getLastReadMessageId());
    }

    @Test
    void addMemberIsNoopForExistingActiveMember() {
        openRoom();
        userOk(7L);
        when(members.findByConversationIdAndUserId(500L, 7L))
                .thenReturn(Optional.of(ConversationMember.of(500L, 7L, ConversationMember.Role.MEMBER)));

        assertTrue(rooms.addMember(RoomKind.COMMUNITY, 10L, 7L));

        verify(members, never()).save(any());
    }

    @Test
    void suspendedDeletedUnverifiedOrMissingUsersAreNotAdded() {
        openRoom();
        for (UserStatus st : new UserStatus[] {UserStatus.SUSPENDED, UserStatus.DELETED}) {
            User u = new User();
            u.setId(8L);
            u.setEmailVerified(true);
            u.setStatus(st);
            when(users.findById(8L)).thenReturn(Optional.of(u));
            assertFalse(rooms.addMember(RoomKind.COMMUNITY, 10L, 8L), st.name());
        }
        User unverified = new User();
        unverified.setId(9L);
        when(users.findById(9L)).thenReturn(Optional.of(unverified));
        assertFalse(rooms.addMember(RoomKind.COMMUNITY, 10L, 9L));
        when(users.findById(11L)).thenReturn(Optional.empty());
        assertFalse(rooms.addMember(RoomKind.COMMUNITY, 10L, 11L));

        verify(members, never()).save(any());
    }

    @Test
    void roomLimitIsConfigurableAndSeparateFromGroupLimit() {
        openRoom();
        userOk(7L);
        when(members.findByConversationIdAndUserId(500L, 7L)).thenReturn(Optional.empty());
        when(members.countByConversationIdAndLeftAtIsNull(500L)).thenReturn(3L);

        ApiException e = assertThrows(ApiException.class, () -> rooms.addMember(RoomKind.COMMUNITY, 10L, 7L));

        assertEquals("ROOM_FULL", e.code());
        assertEquals("3", e.args()[0]);
        // 50'den buyuk bir oda siniri de calisir (normal grup siniri odayi etkilemez)
        RoomConversations big = new RoomConversations(links, convs, members, users, 500);
        when(members.countByConversationIdAndLeftAtIsNull(500L)).thenReturn(120L);
        assertTrue(big.addMember(RoomKind.COMMUNITY, 10L, 7L));
    }

    @Test
    void addMembersStopsQuietlyWhenFull() {
        openRoom();
        userOk(1L);
        userOk(2L);
        when(members.findByConversationIdAndUserId(anyLong(), anyLong())).thenReturn(Optional.empty());
        when(members.countByConversationIdAndLeftAtIsNull(500L)).thenReturn(2L).thenReturn(3L);

        int n = rooms.addMembers(RoomKind.COMMUNITY, 10L, List.of(1L, 2L));

        assertEquals(1, n);
    }

    @Test
    void closedOrMissingRoomAcceptsNobody() {
        when(links.findByKindAndRefId(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.of(link(true)));
        assertFalse(rooms.addMember(RoomKind.COMMUNITY, 10L, 7L));
        assertEquals(0, rooms.addMembers(RoomKind.COMMUNITY, 10L, List.of(7L)));
        when(links.findByKindAndRefId(RoomKind.COMMUNITY, 11L)).thenReturn(Optional.empty());
        assertFalse(rooms.addMember(RoomKind.COMMUNITY, 11L, 7L));
    }

    @Test
    void removeMemberSetsLeftAt() {
        openRoom();
        ConversationMember m = ConversationMember.of(500L, 7L, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(500L, 7L)).thenReturn(Optional.of(m));

        assertTrue(rooms.removeMember(RoomKind.COMMUNITY, 10L, 7L));

        assertNotNull(m.getLeftAt());
        assertFalse(rooms.removeMember(RoomKind.COMMUNITY, 10L, 99L)); // uye degil: no-op
    }

    @Test
    void closeRoomMarksClosedAndEveryoneLeaves() {
        ChatRoomLink l = link(false);
        when(links.findByKindAndRefId(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.of(l));

        rooms.closeRoom(RoomKind.COMMUNITY, 10L);

        assertTrue(l.isClosed());
        verify(links).leaveAll(eq(500L), any());
        rooms.closeRoom(RoomKind.COMMUNITY, 404L); // olmayan oda: sessizce gecer
    }

    @Test
    void openRoomReopensAndReAddsGivenMembers() {
        ChatRoomLink l = link(true);
        when(links.findByKindAndRefId(RoomKind.COMMUNITY, 10L)).thenReturn(Optional.of(l));
        Conversation c = new Conversation();
        c.setId(500L);
        when(convs.findById(500L)).thenReturn(Optional.of(c));
        userOk(1L);
        when(members.findByConversationIdAndUserId(500L, 1L)).thenReturn(Optional.empty());

        rooms.openRoom(RoomKind.COMMUNITY, 10L, List.of(1L));

        assertFalse(l.isClosed());
        verify(members).save(org.mockito.ArgumentMatchers.argThat(m -> m.getUserId().equals(1L)));
    }

    @Test
    void renameCutsAndSaves() {
        openRoom();
        Conversation c = convs.findById(500L).orElseThrow();

        rooms.renameRoom(RoomKind.COMMUNITY, 10L, "Yeni Ad");

        assertEquals("Yeni Ad", c.getTitle());
    }

    @Test
    void purgeDelegatesToRepository() {
        when(links.purgeInactiveUsers(any())).thenReturn(4);

        assertEquals(4, rooms.purgeInactiveUsers());
    }
}
