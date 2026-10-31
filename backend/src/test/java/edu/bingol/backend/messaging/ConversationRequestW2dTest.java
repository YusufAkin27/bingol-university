package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** T-026 / K-08: ilk DM ortak baglam yoksa istek; grup daveti ekleyenle riza yoksa kabul bekler; kabul/red. */
class ConversationRequestW2dTest {

    private final ConversationRepository convs = mock(ConversationRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final MessageRequestPolicy policy = mock(MessageRequestPolicy.class);
    private final ConversationService service =
            new ConversationService(convs, members, mock(MessageRepository.class), users, blocks, mock(MessageCodec.class));

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
        c.setCreatedBy(1L);
        return c;
    }

    private List<ConversationMember> savedMembers(int n) {
        ArgumentCaptor<ConversationMember> cap = ArgumentCaptor.forClass(ConversationMember.class);
        verify(members, times(n)).save(cap.capture());
        return cap.getAllValues();
    }

    @Test
    void firstDirectMessageWithoutSharedContextBecomesARequestForTheRecipient() {
        service.setRequestPolicy(policy);
        when(policy.directAllowed(1L, 2L)).thenReturn(false);
        when(users.findAllById(any())).thenReturn(List.of(user(2L)));
        when(convs.insertDirect(eq("1:2"), eq(1L), any())).thenReturn(1);
        when(convs.findByDirectKey("1:2")).thenReturn(Optional.of(conv(7L, Conversation.Type.DIRECT)));

        service.openDirect(1L, 2L);

        List<ConversationMember> saved = savedMembers(2);
        assertEquals(ConversationMember.RequestState.ACCEPTED, saved.get(0).getRequestState()); // acan taraf
        assertEquals(ConversationMember.RequestState.PENDING, saved.get(1).getRequestState());  // alici
    }

    @Test
    void sharedContextOpensDirectlyWithoutARequest() {
        service.setRequestPolicy(policy);
        when(policy.directAllowed(1L, 2L)).thenReturn(true);
        when(users.findAllById(any())).thenReturn(List.of(user(2L)));
        when(convs.insertDirect(eq("1:2"), eq(1L), any())).thenReturn(1);
        when(convs.findByDirectKey("1:2")).thenReturn(Optional.of(conv(7L, Conversation.Type.DIRECT)));

        service.openDirect(1L, 2L);

        savedMembers(2).forEach(m -> assertTrue(m.isAccepted()));
    }

    @Test
    void openingAnExistingRequestMyselfAcceptsIt() {
        service.setRequestPolicy(policy);
        when(users.findAllById(any())).thenReturn(List.of(user(1L)));
        when(convs.insertDirect(eq("1:2"), eq(2L), any())).thenReturn(0);
        when(convs.findByDirectKey("1:2")).thenReturn(Optional.of(conv(7L, Conversation.Type.DIRECT)));
        ConversationMember mine = ConversationMember.of(7L, 2L, ConversationMember.Role.MEMBER);
        mine.setRequestState(ConversationMember.RequestState.DECLINED);
        when(members.findByConversationIdAndUserId(7L, 2L)).thenReturn(Optional.of(mine));

        service.openDirect(2L, 1L); // 2 numarali kullanici, daha once reddettigi kisiyle sohbeti kendisi aciyor

        assertTrue(mine.isAccepted());
        verify(members).save(mine);
    }

    @Test
    void groupInviteNeedsAcceptanceUnlessInviteeAlreadyConsentedToTheAdder() {
        service.setRequestPolicy(policy);
        when(policy.groupInviteAllowed(1L, 2L)).thenReturn(true);  // 2 beni takip ediyor
        when(policy.groupInviteAllowed(1L, 3L)).thenReturn(false); // 3 yabanci
        when(users.findAllById(any())).thenReturn(List.of(user(2L), user(3L)));
        when(blocks.hiddenFrom(1L)).thenReturn(java.util.Set.of());
        when(convs.save(any(Conversation.class))).thenAnswer(i -> {
            Conversation c = i.getArgument(0);
            c.setId(9L);
            c.setCreatedAt(java.time.Instant.now());
            return c;
        });

        service.createGroup(1L, "Grup", List.of(2L, 3L));

        List<ConversationMember> saved = savedMembers(3);
        assertTrue(saved.get(0).isAccepted()); // kurucu
        assertEquals(ConversationMember.RequestState.ACCEPTED, saved.get(1).getRequestState());
        assertEquals(ConversationMember.RequestState.PENDING, saved.get(2).getRequestState());
    }

    @Test
    void acceptMovesRequestIntoTheMainList() {
        ConversationMember m = ConversationMember.of(7L, 2L, ConversationMember.Role.MEMBER);
        m.setRequestState(ConversationMember.RequestState.PENDING);
        m.setHiddenAt(java.time.Instant.now());
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(7L, 2L)).thenReturn(Optional.of(m));
        when(convs.findById(7L)).thenReturn(Optional.of(conv(7L, Conversation.Type.DIRECT)));

        assertNotNull(service.accept(2L, 7L));

        assertTrue(m.isAccepted());
        assertEquals(null, m.getHiddenAt());
    }

    @Test
    void declineOfDirectRequestKeepsRowButMarksDeclined() {
        ConversationMember m = ConversationMember.of(7L, 2L, ConversationMember.Role.MEMBER);
        m.setRequestState(ConversationMember.RequestState.PENDING);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(7L, 2L)).thenReturn(Optional.of(m));
        when(convs.findById(7L)).thenReturn(Optional.of(conv(7L, Conversation.Type.DIRECT)));

        service.decline(2L, 7L);

        assertEquals(ConversationMember.RequestState.DECLINED, m.getRequestState());
        assertEquals(null, m.getLeftAt());
    }

    @Test
    void declineOfGroupInviteLeavesTheGroup() {
        ConversationMember m = ConversationMember.of(9L, 3L, ConversationMember.Role.MEMBER);
        m.setRequestState(ConversationMember.RequestState.PENDING);
        m.setAddedBy(1L);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(9L, 3L)).thenReturn(Optional.of(m));
        when(convs.findById(9L)).thenReturn(Optional.of(conv(9L, Conversation.Type.GROUP)));

        service.decline(3L, 9L);

        assertNotNull(m.getLeftAt());
    }

    @Test
    void declineOnAnAcceptedConversationIsRejected() {
        ConversationMember m = ConversationMember.of(7L, 2L, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(7L, 2L)).thenReturn(Optional.of(m));
        when(convs.findById(7L)).thenReturn(Optional.of(conv(7L, Conversation.Type.DIRECT)));

        ApiException e = assertThrows(ApiException.class, () -> service.decline(2L, 7L));

        assertEquals("REQUEST_NOT_PENDING", e.code());
        verify(members, times(0)).save(any());
    }

    @Test
    void requestCountComesFromTheRepository() {
        when(members.countPending(5L)).thenReturn(4L);

        assertEquals(4L, service.requestCount(5L));
        verify(members).countPending(anyLong());
    }
}
