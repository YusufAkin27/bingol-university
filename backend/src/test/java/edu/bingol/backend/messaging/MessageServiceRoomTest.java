package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.Mockito.doThrow;
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
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * FIX-P03: (K2) kulup/etkinlik odasi ve 20+ uyeli gruplarda okundu / "yaziyor" olaylari yayinlanmaz, oda basina yavas
 * mod; (A02#13) mesaj istegi kabulu dogrulama hatasinda kalici olmaz.
 */
class MessageServiceRoomTest {

    private static final Long ME = 1L;
    private static final Long OTHER = 2L;
    private static final Long CONV = 10L;

    private final ConversationRepository convs = mock(ConversationRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final MessageRepository messages = mock(MessageRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final ChatEventBus bus = mock(ChatEventBus.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final MessageCodec codec = mock(MessageCodec.class);
    private final ReceiptPolicy policy = mock(ReceiptPolicy.class);
    private final MessageService service = new MessageService(convs, members, messages, users, blocks, limiter, bus,
            mock(PresenceService.class), notifications, mock(ReportService.class), mock(PlatformTransactionManager.class),
            codec, new MessageViewAssembler(messages, mock(MessageReactionRepository.class), codec));

    private Conversation room;
    private ConversationMember me;

    @BeforeEach
    void setUp() {
        service.setPolicy(policy);
        room = new Conversation();
        room.setId(CONV);
        room.setType(Conversation.Type.GROUP);
        room.setLastMessageId(50L);
        when(convs.findById(CONV)).thenReturn(Optional.of(room));
        me = ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER);
        ConversationMember other = ConversationMember.of(CONV, OTHER, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, ME)).thenReturn(Optional.of(me));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(me, other));
        User u = new User();
        u.setId(ME);
        when(users.findById(ME)).thenReturn(Optional.of(u));
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
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
        when(policy.tracked(any(Conversation.class))).thenReturn(false);
        when(policy.tracked(anyLong())).thenReturn(false);
    }

    @Test
    void readInUntrackedConversationAdvancesOwnCursorButPublishesNothingToMembers() {
        when(members.advanceRead(CONV, ME, 50L)).thenReturn(1);

        service.markRead(ME, CONV, 50L);

        verify(members).advanceRead(CONV, ME, 50L); // kendi imleci ilerler (okunmamis sayaci dogru kalir)
        verify(bus, never()).publish(eq("read-receipts"), anyCollection(), any());
        // uyeleri yuklemek bile yok: odada 499 satirlik sorgu ve N alicili olay uretilmez
        verify(members, never()).findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(anyLong());
    }

    @Test
    void readInTrackedConversationStillPublishes() {
        when(policy.tracked(any(Conversation.class))).thenReturn(true);
        when(members.advanceRead(CONV, ME, 50L)).thenReturn(1);

        service.markRead(ME, CONV, 50L);

        verify(bus).publish(eq("read-receipts"), eq(List.of(OTHER)), any());
    }

    @Test
    void typingInUntrackedConversationIsNotPublished() {
        service.typing(ME, CONV);

        verify(bus, never()).publish(eq("typing"), anyCollection(), any());
        verify(members, never()).findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(anyLong());
    }

    @Test
    void typingInTrackedConversationIsPublished() {
        when(policy.tracked(anyLong())).thenReturn(true);

        service.typing(ME, CONV);

        verify(bus).publish(eq("typing"), eq(List.of(OTHER)), any());
    }

    @Test
    void roomHasPerRoomSlowMode() {
        when(policy.isRoom(CONV)).thenReturn(true);

        service.send(ME, CONV, "merhaba oda", "c1");

        verify(limiter).check("msg:room:" + CONV, MessageService.ROOM_SEND_PER_MINUTE, Duration.ofMinutes(1));
    }

    @Test
    void slowModeIsNotAppliedToPlainGroups() {
        when(policy.isRoom(CONV)).thenReturn(false);

        service.send(ME, CONV, "merhaba grup", "c2");

        verify(limiter, never()).check(startsWith("msg:room:"), anyInt(), any());
    }

    @Test
    void roomSlowModeBlocksTheSendBeforeAnythingIsWritten() {
        when(policy.isRoom(CONV)).thenReturn(true);
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "cok sik"))
                .when(limiter).check(startsWith("msg:room:"), anyInt(), any());

        assertThrows(ApiException.class, () -> service.send(ME, CONV, "x", "c3"));

        verify(messages, never()).saveAndFlush(any());
        assertTrue(true);
    }

    // ---------------------------------------------------------------- A02#13 kabul, dogrulamadan once yazilmaz

    @Test
    void pendingRecipientIsNotAcceptedWhenTheSendIsRejectedByTheRateLimit() {
        room.setType(Conversation.Type.DIRECT);
        me.setRequestState(ConversationMember.RequestState.PENDING);
        ConversationMember peer = ConversationMember.of(CONV, OTHER, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(me, peer));
        User p = new User();
        p.setId(OTHER);
        when(users.findById(OTHER)).thenReturn(Optional.of(p));
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "cok sik"))
                .when(limiter).check(startsWith("msg:user:"), anyInt(), any());

        assertThrows(ApiException.class, () -> service.send(ME, CONV, "yanit", "r1"));

        assertFalse(me.isAccepted(), "reddedilen gonderim istegi kabul etmis sayilmamali");
        verify(members, never()).save(any(ConversationMember.class));
    }

    @Test
    void pendingRecipientIsAcceptedTogetherWithTheMessage() {
        room.setType(Conversation.Type.DIRECT);
        me.setRequestState(ConversationMember.RequestState.PENDING);
        ConversationMember peer = ConversationMember.of(CONV, OTHER, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(me, peer));
        User p = new User();
        p.setId(OTHER);
        when(users.findById(OTHER)).thenReturn(Optional.of(p));

        service.send(ME, CONV, "yanit", "r2");

        assertTrue(me.isAccepted());
        verify(members).save(me);
        assertEquals(1, org.mockito.Mockito.mockingDetails(messages).getInvocations().stream()
                .filter(i -> i.getMethod().getName().equals("saveAndFlush")).count());
    }
}
