package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReceiptEvent;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** Iletildi / okundu makbuzlari: durum kurali (birebir + grup), geri gitmeyen ack, olay yayini. */
class ReceiptServiceTest {

    static final Long CID = 10L;
    static final Long A = 1L; // gonderen
    static final Long B = 2L;
    static final Long C = 3L;
    static final Instant T0 = Instant.parse("2026-01-01T00:00:00Z");

    final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    final ConversationRepository convs = mock(ConversationRepository.class);
    final MessageRepository messages = mock(MessageRepository.class);
    final UserRepository users = mock(UserRepository.class);
    final BlockService blocks = mock(BlockService.class);
    final ChatEventBus bus = mock(ChatEventBus.class);
    final ReceiptService svc = new ReceiptService(members, convs, messages, users, blocks, bus);

    Conversation conv;
    List<ConversationMember> active;

    @BeforeEach
    void setUp() {
        conv = new Conversation();
        conv.setId(CID);
        conv.setType(Conversation.Type.DIRECT);
        conv.setLastMessageId(50L);
        when(convs.findById(CID)).thenReturn(Optional.of(conv));
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(users.findAllById(any())).thenReturn(List.of());
        active = new ArrayList<>();
    }

    ConversationMember member(Long uid, long delivered, long read) {
        ConversationMember m = ConversationMember.of(CID, uid, ConversationMember.Role.MEMBER);
        m.setJoinedAt(T0);
        m.setLastDeliveredMessageId(delivered);
        m.setLastReadMessageId(read);
        return m;
    }

    Message msg(long id, Long sender) {
        Message m = new Message();
        m.setId(id);
        m.setConversationId(CID);
        m.setSenderId(sender);
        m.setClientId("c" + id);
        m.setCreatedAt(T0.plusSeconds(id));
        return m;
    }

    void group(ConversationMember... ms) {
        conv.setType(Conversation.Type.GROUP);
        active = new ArrayList<>(List.of(ms));
        when(members.findByConversationIdInAndLeftAtIsNull(any())).thenAnswer(inv -> active);
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CID)).thenAnswer(inv -> active);
    }

    String status(Message m, Long viewer) {
        return svc.statuses(viewer, List.of(m), null, null).get(m.getId());
    }

    @Test
    void directMovesSentDeliveredRead() {
        group(member(A, 0, 0), member(B, 0, 0));
        conv.setType(Conversation.Type.DIRECT);
        Message m = msg(7, A);
        assertEquals("SENT", status(m, A));

        active.get(1).setLastDeliveredMessageId(7L);
        assertEquals("DELIVERED", status(m, A));

        active.get(1).setLastReadMessageId(7L);
        assertEquals("READ", status(m, A));
    }

    @Test
    void statusOnlyForViewersOwnMessages() {
        group(member(A, 0, 0), member(B, 9, 9));
        assertTrue(svc.statuses(B, List.of(msg(7, A)), null, null).isEmpty()); // baskasinin mesaji: durum yok
    }

    @Test
    void groupNeedsAllOtherMembers() {
        group(member(A, 0, 0), member(B, 7, 7), member(C, 0, 0));
        Message m = msg(7, A);
        assertEquals("SENT", status(m, A)); // yalniz biri iletildi -> hala SENT

        active.get(2).setLastDeliveredMessageId(7L);
        assertEquals("DELIVERED", status(m, A)); // B okudu ama C yalniz iletildi

        active.get(2).setLastReadMessageId(7L);
        assertEquals("READ", status(m, A));
    }

    @Test
    void leftBlockedAndSuspendedMembersAreIgnored() {
        // C ayrildi: aktif listede yok
        group(member(A, 0, 0), member(B, 7, 7));
        assertEquals("READ", status(msg(7, A), A));

        // engelli
        group(member(A, 0, 0), member(B, 7, 7), member(C, 0, 0));
        when(blocks.hiddenFrom(A)).thenReturn(Set.of(C));
        assertEquals("READ", status(msg(7, A), A));

        // askida
        when(blocks.hiddenFrom(A)).thenReturn(Set.of());
        User suspended = new User();
        suspended.setId(C);
        suspended.setStatus(UserStatus.SUSPENDED);
        when(users.findAllById(any())).thenReturn(List.of(suspended));
        assertEquals("READ", status(msg(7, A), A));
    }

    @Test
    void memberWhoJoinedAfterMessageDoesNotBlockStatus() {
        ConversationMember late = member(C, 0, 0);
        late.setJoinedAt(T0.plusSeconds(100));
        group(member(A, 0, 0), member(B, 7, 7), late);
        assertEquals("READ", status(msg(7, A), A));
    }

    @Test
    void noRecipientsMeansSent() {
        group(member(A, 0, 0));
        assertEquals("SENT", status(msg(7, A), A));
    }

    @Test
    void deliveredAckAdvancesForwardAndPublishesToPeerInDirect() {
        group(member(A, 0, 0), member(B, 3, 3));
        conv.setType(Conversation.Type.DIRECT);
        ConversationMember me = active.get(1);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CID, B)).thenReturn(Optional.of(me));
        when(messages.maxIdFromOthers(CID, 9L, B)).thenReturn(9L);
        when(members.advanceDelivered(CID, B, 9L)).thenReturn(1);

        svc.markDelivered(B, CID, 9L);

        ArgumentCaptor<Object> payload = ArgumentCaptor.forClass(Object.class);
        verify(bus).publish(eq("message-events"), eq(List.of(A)), payload.capture());
        ReceiptEvent ev = (ReceiptEvent) payload.getValue();
        assertEquals("receipt", ev.type());
        assertEquals("delivered", ev.kind());
        assertEquals(9L, ev.upToMessageId());
        assertEquals(B, ev.userId());
        assertEquals("DELIVERED", ev.status());
        assertEquals(CID, ev.conversationId());
    }

    @Test
    void ackNeverMovesBackwardAndOwnMessagesAreIgnored() {
        group(member(A, 0, 0), member(B, 20, 5));
        conv.setType(Conversation.Type.DIRECT);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CID, B)).thenReturn(Optional.of(active.get(1)));
        // geriye gitme: hedef <= mevcut iletildi
        when(messages.maxIdFromOthers(CID, 10L, B)).thenReturn(10L);
        svc.markDelivered(B, CID, 10L);
        // yalniz kendi mesajlari: hedef yok
        when(messages.maxIdFromOthers(CID, 40L, B)).thenReturn(null);
        svc.markDelivered(B, CID, 40L);
        verify(members, never()).advanceDelivered(anyLong(), anyLong(), anyLong());
        verify(bus, never()).publish(any(), anyCollection(), any());
    }

    @Test
    void ackIsClampedToLastMessageAndRejectsNonMember() {
        group(member(A, 0, 0), member(B, 0, 0));
        conv.setType(Conversation.Type.DIRECT);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CID, B)).thenReturn(Optional.of(active.get(1)));
        when(messages.maxIdFromOthers(CID, 50L, B)).thenReturn(49L);
        when(members.advanceDelivered(CID, B, 49L)).thenReturn(1);
        svc.markDelivered(B, CID, 9999L); // son mesaj 50: sinirlanir
        verify(members).advanceDelivered(CID, B, 49L);

        ApiException e = assertThrows(ApiException.class, () -> svc.markDelivered(99L, CID, 5L));
        assertEquals("CONVERSATION_NOT_FOUND", e.code());
        assertThrows(ApiException.class, () -> svc.markDelivered(B, CID, 0L));
    }

    @Test
    void groupDeliveredEventOnlyWhenAllMembersReached() {
        // A, 5 numarali mesaji gonderdi; B zaten iletildi; C simdi ack atiyor
        group(member(A, 0, 0), member(B, 5, 0), member(C, 5, 0)); // C'nin imleci advance sonrasi 5
        Message m5 = msg(5, A);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CID, C))
                .thenReturn(Optional.of(member(C, 0, 0)));
        when(messages.maxIdFromOthers(CID, 5L, C)).thenReturn(5L);
        when(members.advanceDelivered(CID, C, 5L)).thenReturn(1);
        when(messages.sendersInRange(CID, 0L, 5L, C)).thenReturn(List.of(A));
        when(messages.ownedInRange(eq(CID), eq(A), eq(0L), eq(5L), any())).thenReturn(List.of(m5));

        svc.markDelivered(C, CID, 5L);

        ArgumentCaptor<Object> payload = ArgumentCaptor.forClass(Object.class);
        verify(bus).publish(eq("message-events"), eq(List.of(A)), payload.capture());
        ReceiptEvent ev = (ReceiptEvent) payload.getValue();
        assertEquals(5L, ev.upToMessageId());
        assertEquals("DELIVERED", ev.status());
    }

    @Test
    void groupEventNotSentWhileSomeoneLags() {
        group(member(A, 0, 0), member(B, 0, 0), member(C, 5, 0)); // B hala iletilmedi
        Message m5 = msg(5, A);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CID, C)).thenReturn(Optional.of(member(C, 0, 0)));
        when(messages.maxIdFromOthers(CID, 5L, C)).thenReturn(5L);
        when(members.advanceDelivered(CID, C, 5L)).thenReturn(1);
        when(messages.sendersInRange(CID, 0L, 5L, C)).thenReturn(List.of(A));
        when(messages.ownedInRange(eq(CID), eq(A), eq(0L), eq(5L), any())).thenReturn(List.of(m5));

        svc.markDelivered(C, CID, 5L);

        verify(bus, never()).publish(any(), anyCollection(), any());
    }

    @Test
    void blockedPeerDoesNotReceiveReceipts() {
        group(member(A, 0, 0), member(B, 0, 0));
        conv.setType(Conversation.Type.DIRECT);
        when(blocks.hiddenFrom(B)).thenReturn(Set.of(A));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CID, B)).thenReturn(Optional.of(active.get(1)));
        when(messages.maxIdFromOthers(CID, 9L, B)).thenReturn(9L);
        when(members.advanceDelivered(CID, B, 9L)).thenReturn(1);

        svc.markDelivered(B, CID, 9L);

        verify(bus, never()).publish(any(), anyCollection(), any());
    }

    @Test
    void readPublishesReadAndDeliveredWhenDeliveredCursorAlsoMoved() {
        group(member(A, 0, 0), member(B, 0, 0));
        conv.setType(Conversation.Type.DIRECT);

        svc.onRead(B, CID, 2L, 2L, 9L);

        ArgumentCaptor<Object> payload = ArgumentCaptor.forClass(Object.class);
        verify(bus, org.mockito.Mockito.times(2)).publish(eq("message-events"), eq(List.of(A)), payload.capture());
        List<Object> all = payload.getAllValues();
        assertEquals("delivered", ((ReceiptEvent) all.get(0)).kind());
        ReceiptEvent read = (ReceiptEvent) all.get(1);
        assertEquals("read", read.kind());
        assertEquals("READ", read.status());
        assertEquals(9L, read.upToMessageId());
    }

    @Test
    void readDoesNotRepublishDeliveredWhenAlreadyDelivered() {
        group(member(A, 0, 0), member(B, 0, 0));
        conv.setType(Conversation.Type.DIRECT);

        svc.onRead(B, CID, 2L, 9L, 9L);

        verify(bus, org.mockito.Mockito.times(1)).publish(eq("message-events"), any(), any());
    }

    @Test
    void statusIsNullInDtoForOthersMessagesAndSetByWithStatus() {
        var v = edu.bingol.backend.messaging.dto.MessagingDtos.MessageView.of(msg(1, A));
        assertNull(v.status());
        assertEquals("READ", v.withStatus("READ").status());
        assertEquals("READ", v.withStatus("READ").withExtras(null, List.of(), null).status());
        assertEquals("READ", v.withStatus("READ").withAttachments(List.of()).status());
        assertEquals(Map.of(), svc.statuses(B, List.of(msg(1, A)), null, null));
    }

    @Test
    void suppressedMessageNeverLeavesSentEvenIfPeerReadEverything() {
        group(member(A, 0, 0), member(B, 99, 99));
        conv.setType(Conversation.Type.DIRECT);
        Message m = msg(7, A);
        m.setSuppressed(true);
        assertEquals("SENT", status(m, A));
    }

    @Test
    void directReceiptEventStopsBeforeSuppressedMessage() {
        group(member(A, 0, 0), member(B, 0, 0));
        conv.setType(Conversation.Type.DIRECT);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CID, B)).thenReturn(Optional.of(active.get(1)));
        when(messages.maxIdFromOthers(CID, 9L, B)).thenReturn(9L);
        when(members.advanceDelivered(CID, B, 9L)).thenReturn(1);
        when(messages.minSuppressedId(CID, A, 0L, 9L)).thenReturn(6L); // 6 ve sonrasi bastirilmis

        svc.markDelivered(B, CID, 9L);

        ArgumentCaptor<Object> payload = ArgumentCaptor.forClass(Object.class);
        verify(bus).publish(eq("message-events"), eq(List.of(A)), payload.capture());
        assertEquals(5L, ((ReceiptEvent) payload.getValue()).upToMessageId());
    }
}
