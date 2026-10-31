package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.messaging.ws.PresenceService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.transaction.PlatformTransactionManager;

/** T-026 / K-08: mesaj istegi. Bekleyen alici icin WS/bildirim/makbuz yok; yanitsiz gonderen en fazla 3 mesaj yazar. */
class MessageRequestW2dTest {

    private static final Long ME = 1L;
    private static final Long PEER = 2L;
    private static final Long CONV = 10L;

    private final ConversationRepository convs = mock(ConversationRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final MessageRepository messages = mock(MessageRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final ChatEventBus bus = mock(ChatEventBus.class);
    private final PresenceService presence = mock(PresenceService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final MessageCodec codec = mock(MessageCodec.class);
    private final MessageViewAssembler assembler =
            new MessageViewAssembler(messages, mock(MessageReactionRepository.class), codec);
    private final MessageService service = new MessageService(convs, members, messages, users, blocks, limiter, bus,
            presence, notifications, mock(ReportService.class), mock(PlatformTransactionManager.class), codec,
            assembler, false);

    private ConversationMember me;
    private ConversationMember peer;

    private static ConversationMember member(long id, ConversationMember.RequestState st) {
        ConversationMember m = ConversationMember.of(CONV, id, ConversationMember.Role.MEMBER);
        m.setRequestState(st);
        return m;
    }

    @BeforeEach
    void setUp() {
        Conversation direct = new Conversation();
        direct.setId(CONV);
        direct.setType(Conversation.Type.DIRECT);
        direct.setLastMessageId(50L);
        when(convs.findById(CONV)).thenReturn(Optional.of(direct));
        me = member(ME, ConversationMember.RequestState.ACCEPTED);
        peer = member(PEER, ConversationMember.RequestState.PENDING);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, ME)).thenReturn(Optional.of(me));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, PEER)).thenReturn(Optional.of(peer));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(me, peer));
        User u1 = new User();
        u1.setId(ME);
        User u2 = new User();
        u2.setId(PEER);
        when(users.findById(ME)).thenReturn(Optional.of(u1));
        when(users.findById(PEER)).thenReturn(Optional.of(u2));
        when(messages.saveAndFlush(any(Message.class))).thenAnswer(inv -> {
            Message m = inv.getArgument(0);
            m.setId(100L);
            return m;
        });
        org.mockito.Mockito.doAnswer(inv -> {
            ((Message) inv.getArgument(0)).setBody(inv.getArgument(1));
            return null;
        }).when(codec).seal(any(Message.class), anyString());
        when(codec.open(any(Message.class))).thenAnswer(inv -> inv.getArgument(0));
        when(codec.openAll(any())).thenAnswer(inv -> inv.getArgument(0));
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
    }

    @Test
    void pendingRecipientGetsNoWebSocketNoPushAndNoNotification() {
        service.send(ME, CONV, "merhaba", "c1");

        ArgumentCaptor<List<Long>> to = ArgumentCaptor.forClass(List.class);
        verify(bus).publish(eq("messages"), to.capture(), any());
        assertEquals(List.of(ME), to.getValue()); // yalniz gondericinin cihazlari
        org.mockito.Mockito.verifyNoInteractions(notifications);
    }

    @Test
    void senderIsLimitedToThreeMessagesUntilTheRequestIsAccepted() {
        when(messages.countSentBy(CONV, ME)).thenReturn(2L);
        service.send(ME, CONV, "uc", "c3"); // 3. mesaj serbest

        when(messages.countSentBy(CONV, ME)).thenReturn(3L);
        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, "dort", "c4"));

        assertEquals("MESSAGE_REQUEST_PENDING", e.code());
        assertEquals(409, e.status().value());
    }

    @Test
    void declinedPeerLooksTheSameToTheSender() {
        peer.setRequestState(ConversationMember.RequestState.DECLINED);
        when(messages.countSentBy(CONV, ME)).thenReturn(3L);

        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, "yine", "c9"));

        assertEquals("MESSAGE_REQUEST_PENDING", e.code()); // reddedildigi ogrenilmez
    }

    @Test
    void recipientReplyingAcceptsTheRequestAndRemovesTheLimit() {
        when(messages.countSentBy(CONV, PEER)).thenReturn(0L);

        service.send(PEER, CONV, "tamam", "r1");

        assertTrue(peer.isAccepted());
        verify(members).save(peer);
    }

    @Test
    void pendingRecipientReadingSendsNoReceiptAndKeepsUnread() {
        service.markRead(PEER, CONV, 50L);

        verify(members, never()).advanceRead(anyLong(), anyLong(), anyLong());
        verify(bus, never()).publish(eq("read-receipts"), anyCollection(), any());
    }

    @Test
    void pendingRecipientTypingIsNotPublished() {
        service.typing(PEER, CONV);

        verify(bus, never()).publish(eq("typing"), anyCollection(), any());
    }

    @Test
    void acceptedPeerMeansNoLimitAndNormalDelivery() {
        peer.setRequestState(ConversationMember.RequestState.ACCEPTED);
        when(messages.countSentBy(CONV, ME)).thenReturn(50L);

        service.send(ME, CONV, "serbest", "c5");

        ArgumentCaptor<List<Long>> to = ArgumentCaptor.forClass(List.class);
        verify(bus).publish(eq("messages"), to.capture(), any());
        assertTrue(to.getValue().contains(PEER));
        assertFalse(to.getValue().isEmpty());
    }
}
