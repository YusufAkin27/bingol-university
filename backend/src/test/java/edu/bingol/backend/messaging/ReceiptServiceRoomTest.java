package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.messaging.dto.MessagingDtos.ReceiptEvent;
import edu.bingol.backend.messaging.room.ChatRoomLink;
import edu.bingol.backend.messaging.room.ChatRoomLinkRepository;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * FIX-P03 (A02#1, A02#2, K2): oda ve 20+ uyeli gruplarda makbuz hesabi/yayini yok; kucuk gruplarda aynen surer.
 */
class ReceiptServiceRoomTest {

    static final Long CID = 10L;
    static final Long A = 1L;
    static final Long B = 2L;
    static final Instant T0 = Instant.parse("2026-01-01T00:00:00Z");

    final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    final ConversationRepository convs = mock(ConversationRepository.class);
    final MessageRepository messages = mock(MessageRepository.class);
    final UserRepository users = mock(UserRepository.class);
    final BlockService blocks = mock(BlockService.class);
    final ChatEventBus bus = mock(ChatEventBus.class);
    final ChatRoomLinkRepository roomLinks = mock(ChatRoomLinkRepository.class);
    final ReceiptPolicy policy = new ReceiptPolicy(members, roomLinks, 20);
    final ReceiptService svc = new ReceiptService(members, convs, messages, users, blocks, bus);

    Conversation conv;

    @BeforeEach
    void setUp() {
        svc.setPolicy(policy);
        conv = new Conversation();
        conv.setId(CID);
        conv.setType(Conversation.Type.GROUP);
        conv.setLastMessageId(50L);
        when(convs.findById(CID)).thenReturn(Optional.of(conv));
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(users.findAllById(any())).thenReturn(List.of());
        when(roomLinks.findByConversationId(CID)).thenReturn(Optional.empty());
        when(roomLinks.findByConversationIdIn(any())).thenReturn(List.of());
    }

    private void activeCount(long n) {
        when(members.countByConversationIdAndLeftAtIsNull(CID)).thenReturn(n);
        when(members.activeCounts(any())).thenReturn(List.<Object[]>of(new Object[] {CID, n}));
    }

    private static ConversationMember member(long uid, long delivered, long read) {
        ConversationMember m = ConversationMember.of(CID, uid, ConversationMember.Role.MEMBER);
        m.setJoinedAt(T0);
        m.setLastDeliveredMessageId(delivered);
        m.setLastReadMessageId(read);
        return m;
    }

    private static Message msg(long id, Long sender) {
        Message m = new Message();
        m.setId(id);
        m.setConversationId(CID);
        m.setSenderId(sender);
        m.setClientId("c" + id);
        m.setCreatedAt(T0.plusSeconds(id));
        return m;
    }

    @Test
    void bigGroupReadDoesNotLoadMembersOrPublishAnything() {
        activeCount(500);

        svc.onRead(B, CID, 2L, 2L, 9L);

        verify(members, never()).findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(anyLong());
        verify(messages, never()).sendersInRange(anyLong(), anyLong(), anyLong(), anyLong());
        verify(bus, never()).publish(any(), anyCollection(), any());
    }

    @Test
    void roomWithFewMembersIsAlsoUntracked() {
        activeCount(5);
        when(roomLinks.findByConversationId(CID)).thenReturn(Optional.of(new ChatRoomLink()));

        svc.onRead(B, CID, 2L, 2L, 9L);

        verify(bus, never()).publish(any(), anyCollection(), any());
        verify(members, never()).findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(anyLong());
    }

    @Test
    void smallPlainGroupStillPublishesGroupReceipts() {
        activeCount(3);
        List<ConversationMember> active = new ArrayList<>(List.of(member(A, 0, 0), member(B, 9, 9), member(3L, 9, 9)));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CID)).thenReturn(active);
        when(messages.sendersInRange(CID, 2L, 9L, B)).thenReturn(List.of(A));
        when(messages.ownedInRange(org.mockito.ArgumentMatchers.eq(CID), org.mockito.ArgumentMatchers.eq(A), anyLong(),
                anyLong(), any())).thenReturn(List.of(msg(5, A)));
        when(members.findByConversationIdInAndLeftAtIsNull(any())).thenReturn(active);

        svc.onRead(B, CID, 2L, 9L, 9L);

        ArgumentCaptor<Object> payload = ArgumentCaptor.forClass(Object.class);
        verify(bus).publish(org.mockito.ArgumentMatchers.eq("message-events"), org.mockito.ArgumentMatchers.eq(List.of(A)),
                payload.capture());
        assertEquals("read", ((ReceiptEvent) payload.getValue()).kind());
    }

    @Test
    void statusesOfBigGroupAreSkippedWithoutLoadingMembersOrUsers() {
        activeCount(500);

        Map<Long, String> st = svc.statuses(A, List.of(msg(7, A)), null, null);

        assertTrue(st.isEmpty(), "buyuk grupta tik durumu hesaplanmaz");
        verify(members, never()).findByConversationIdInAndLeftAtIsNull(any());
        verify(users, never()).findAllById(any());
    }

    @Test
    void statusesOfSmallGroupLoadMembersOnlyForThatGroup() {
        activeCount(3);
        List<ConversationMember> active = List.of(member(A, 0, 0), member(B, 7, 7), member(3L, 7, 7));
        when(members.findByConversationIdInAndLeftAtIsNull(any())).thenReturn(active);

        Map<Long, String> st = svc.statuses(A, List.of(msg(7, A)), null, null);

        assertEquals("READ", st.get(7L));
    }

    @Test
    void policyDecisionsFollowMemberCountAndRoomLink() {
        when(members.countByConversationIdAndLeftAtIsNull(CID)).thenReturn(20L);
        assertTrue(policy.tracked(CID), "tam 20 uye dahil");

        ReceiptPolicy p2 = new ReceiptPolicy(members, roomLinks, 20);
        when(members.countByConversationIdAndLeftAtIsNull(CID)).thenReturn(21L);
        assertFalse(p2.tracked(CID), "21 uye kapali");

        ReceiptPolicy p3 = new ReceiptPolicy(members, roomLinks, 20);
        when(members.countByConversationIdAndLeftAtIsNull(CID)).thenReturn(4L);
        when(roomLinks.findByConversationId(CID)).thenReturn(Optional.of(new ChatRoomLink()));
        assertFalse(p3.tracked(CID), "oda her zaman kapali");

        ReceiptPolicy p4 = new ReceiptPolicy(members, roomLinks, 20);
        when(members.countByConversationIdAndLeftAtIsNull(CID)).thenReturn(2L);
        assertTrue(p4.tracked(CID), "2 uye = birebir: her zaman acik");
        assertTrue(RoomKind.valueOf("EVENT") != null);
    }
}
