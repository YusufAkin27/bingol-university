package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.LongStream;
import org.junit.jupiter.api.Test;

class ConversationServiceTest {

    private final ConversationRepository convs = mock(ConversationRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final MessageRepository messages = mock(MessageRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final MessageCodec codec = mock(MessageCodec.class);
    private final ConversationService service = new ConversationService(convs, members, messages, users, blocks, codec);

    private static User user(long id) {
        User u = new User();
        u.setId(id);
        u.setEmailVerified(true);
        u.setDisplayName("U" + id);
        return u;
    }

    private static Conversation conv(long id, Conversation.Type type) {
        Conversation c = new Conversation();
        c.setId(id);
        c.setType(type);
        return c;
    }

    @Test
    void cannotStartConversationWithSelf() {
        assertEquals("CANNOT_MESSAGE_SELF", assertThrows(ApiException.class, () -> service.openDirect(1L, 1L)).code());
    }

    @Test
    void unverifiedOrMissingTargetIsNotFound() {
        User unverified = user(2L);
        unverified.setEmailVerified(false);
        when(users.findAllById(any())).thenReturn(List.of(unverified));

        assertEquals(404, assertThrows(ApiException.class, () -> service.openDirect(1L, 2L)).status().value());
    }

    @Test
    void directKeyIsOrderIndependent() {
        assertEquals("3:9", Conversation.directKey(9L, 3L));
        assertEquals(Conversation.directKey(3L, 9L), Conversation.directKey(9L, 3L));
    }

    @Test
    void existingDirectConversationIsReturnedWithoutNewMembers() {
        when(users.findAllById(any())).thenReturn(List.of(user(2L)));
        when(convs.insertDirect(eq("1:2"), eq(1L), any())).thenReturn(0); // yaris kaybedildi / zaten var
        when(convs.findByDirectKey("1:2")).thenReturn(Optional.of(conv(7L, Conversation.Type.DIRECT)));

        ConversationService.Opened o = service.openDirect(1L, 2L);

        assertFalse(o.created());
        assertEquals(7L, o.conversation().id());
        verify(members, never()).save(any());
    }

    @Test
    void newDirectConversationCreatesBothMembers() {
        when(users.findAllById(any())).thenReturn(List.of(user(2L)));
        when(convs.insertDirect(eq("1:2"), eq(1L), any())).thenReturn(1);
        when(convs.findByDirectKey("1:2")).thenReturn(Optional.of(conv(7L, Conversation.Type.DIRECT)));

        assertTrue(service.openDirect(1L, 2L).created());
        verify(members, org.mockito.Mockito.times(2)).save(any(ConversationMember.class));
    }

    @Test
    void groupIsLimitedToFiftyMembers() {
        List<Long> ids = LongStream.rangeClosed(2, 51).boxed().toList(); // 50 + olusturan = 51
        assertEquals("GROUP_FULL", assertThrows(ApiException.class, () -> service.createGroup(1L, "Grup", ids)).code());
        verify(convs, never()).save(any());
    }

    @Test
    void groupCannotIncludeBlockedUser() {
        when(users.findAllById(any())).thenReturn(List.of(user(2L), user(3L)));
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of(3L));

        assertEquals("BLOCKED", assertThrows(ApiException.class, () -> service.createGroup(1L, "Grup", List.of(2L, 3L))).code());
    }

    @Test
    void creatorBecomesAdminOfNewGroup() {
        when(users.findAllById(any())).thenReturn(List.of(user(2L)));
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of());
        when(convs.save(any(Conversation.class))).thenAnswer(inv -> {
            Conversation c = inv.getArgument(0);
            c.setId(5L);
            return c;
        });
        List<ConversationMember> saved = new ArrayList<>();
        when(members.save(any(ConversationMember.class))).thenAnswer(inv -> {
            saved.add(inv.getArgument(0));
            return inv.getArgument(0);
        });

        service.createGroup(1L, "  Proje  ", List.of(2L, 1L, 2L));

        assertEquals(2, saved.size());
        assertEquals(ConversationMember.Role.ADMIN, saved.get(0).getRole());
        assertEquals(1L, saved.get(0).getUserId());
        assertEquals(ConversationMember.Role.MEMBER, saved.get(1).getRole());
    }

    @Test
    void onlyGroupAdminCanAddMembersOrRename() {
        Conversation g = conv(5L, Conversation.Type.GROUP);
        when(convs.findById(5L)).thenReturn(Optional.of(g));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 2L))
                .thenReturn(Optional.of(ConversationMember.of(5L, 2L, ConversationMember.Role.MEMBER)));

        assertEquals("NOT_GROUP_ADMIN", assertThrows(ApiException.class, () -> service.addMembers(2L, 5L, List.of(3L))).code());
        assertEquals("NOT_GROUP_ADMIN", assertThrows(ApiException.class, () -> service.rename(2L, 5L, "Yeni")).code());
        assertEquals(404, assertThrows(ApiException.class, () -> service.rename(9L, 5L, "Yeni")).status().value());
    }

    @Test
    void leavingAdminPassesAdminToOldestRemainingMember() {
        when(convs.findById(5L)).thenReturn(Optional.of(conv(5L, Conversation.Type.GROUP)));
        ConversationMember admin = ConversationMember.of(5L, 1L, ConversationMember.Role.ADMIN);
        ConversationMember next = ConversationMember.of(5L, 2L, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 1L)).thenReturn(Optional.of(admin));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(5L)).thenReturn(List.of(next));

        service.leave(1L, 5L);

        assertTrue(admin.getLeftAt() != null);
        assertEquals(ConversationMember.Role.ADMIN, next.getRole());
    }

    @Test
    void cannotLeaveDirectConversation() {
        when(convs.findById(5L)).thenReturn(Optional.of(conv(5L, Conversation.Type.DIRECT)));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 1L))
                .thenReturn(Optional.of(ConversationMember.of(5L, 1L, ConversationMember.Role.MEMBER)));

        assertEquals("NOT_A_GROUP", assertThrows(ApiException.class, () -> service.leave(1L, 5L)).code());
    }

    @Test
    void lateJoinerDoesNotSeeLastMessageThatPredatesJoinInListPreview() {
        Conversation g = conv(5L, Conversation.Type.GROUP);
        g.setLastMessageId(40L);
        ConversationMember late = ConversationMember.of(5L, 2L, ConversationMember.Role.MEMBER);
        late.setJoinedAt(java.time.Instant.now());
        Message old = new Message();
        old.setId(40L);
        old.setConversationId(5L);
        old.setSenderId(1L);
        old.setBody("katilmadan once yazildi");
        old.setCreatedAt(late.getJoinedAt().minusSeconds(60));
        when(members.findByConversationIdInAndLeftAtIsNull(any())).thenReturn(List.of(
                ConversationMember.of(5L, 1L, ConversationMember.Role.ADMIN), late));
        when(messages.findAllById(any())).thenReturn(List.of(old));
        when(messages.unreadCounts(anyLong(), any(), any())).thenReturn(List.of());
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(convs.page(eq(2L), any(), anyBoolean(), any())).thenReturn(List.of(g));
        when(convs.findById(5L)).thenReturn(Optional.of(g));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 2L)).thenReturn(Optional.of(late));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(5L)).thenReturn(List.of(late));
        when(users.findAllById(any())).thenReturn(List.of(user(2L)));

        assertEquals(null, service.list(2L, null, 20).items().get(0).lastMessage());
        assertEquals(null, service.detail(2L, 5L).conversation().lastMessage());
    }

    @Test
    void memberWhoJoinedBeforeLastMessageSeesPreview() {
        Conversation g = conv(5L, Conversation.Type.GROUP);
        g.setLastMessageId(40L);
        ConversationMember early = ConversationMember.of(5L, 2L, ConversationMember.Role.MEMBER);
        early.setJoinedAt(java.time.Instant.now().minusSeconds(3600));
        Message last = new Message();
        last.setId(40L);
        last.setConversationId(5L);
        last.setSenderId(1L);
        last.setBody("merhaba");
        when(members.findByConversationIdInAndLeftAtIsNull(any())).thenReturn(List.of(early));
        when(messages.findAllById(any())).thenReturn(List.of(last));
        when(messages.unreadCounts(anyLong(), any(), any())).thenReturn(List.of());
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(convs.page(eq(2L), any(), anyBoolean(), any())).thenReturn(List.of(g));

        assertEquals("merhaba", service.list(2L, null, 20).items().get(0).lastMessage().text());
    }
}
