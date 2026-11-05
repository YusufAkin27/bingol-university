package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class MessageInfoControllerTest {
    final MessageRepository messages = mock(MessageRepository.class);
    final ConversationRepository conversations = mock(ConversationRepository.class);
    final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    final MessageCodec codec = mock(MessageCodec.class);
    final MessageViewAssembler assembler = mock(MessageViewAssembler.class);
    final ReceiptService receipts = mock(ReceiptService.class);
    final MessageInfoController controller = new MessageInfoController(messages, conversations, members,
            codec, assembler, receipts, mock(RateLimiter.class));
    Message message;
    ConversationMember member;
    Conversation conversation;

    @BeforeEach void setup() {
        message = new Message(); message.setId(10L); message.setConversationId(5L); message.setSenderId(1L);
        message.setBody("Hello"); message.setCreatedAt(Instant.parse("2026-11-04T10:00:00Z"));
        member = ConversationMember.of(5L, 1L, ConversationMember.Role.MEMBER);
        conversation = new Conversation(); conversation.setId(5L); conversation.setType(Conversation.Type.DIRECT);
        when(messages.findById(10L)).thenReturn(Optional.of(message));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 1L)).thenReturn(Optional.of(member));
        when(conversations.findById(5L)).thenReturn(Optional.of(conversation));
        when(messages.repliesTo(anyLong(), anyLong(), anyLong(), anyLong(), nullable(Long.class), any())).thenReturn(List.of());
        when(assembler.assemble(anyLong(), anyList(), anySet(), isNull())).thenAnswer(call ->
            ((List<Message>) call.getArgument(1)).stream().map(m -> MessageView.of(m, false)).toList());
        when(receipts.statuses(anyLong(), anyCollection(), isNull(), anyMap())).thenReturn(Map.of(10L, "READ"));
    }
    @Test void historicalTimesStayUnknown() {
        var result = controller.details(1L, 10L, null, 20);
        assertEquals("2026-11-04T10:00:00Z", result.sentAt());
        assertNull(result.deliveredAt()); assertNull(result.readAt()); assertEquals("READ", result.status());
    }
    @Test void onlySenderMayReadDetails() {
        message.setSenderId(2L);
        assertThrows(ApiException.class, () -> controller.details(1L, 10L, null, 20));
        verifyNoInteractions(codec, assembler);
    }
    @Test void clearedMessagesAndGroupChatsAreHidden() {
        member.setClearedUpToMessageId(10L);
        assertThrows(ApiException.class, () -> controller.details(1L, 10L, null, 20));
        member.setClearedUpToMessageId(0L); conversation.setType(Conversation.Type.GROUP);
        assertThrows(ApiException.class, () -> controller.details(1L, 10L, null, 20));
    }
    @Test void returnsOnlyRecordedTimesAndPagesReplies() {
        message.setDeliveredAt(Instant.parse("2026-11-04T10:00:01Z"));
        message.setReadAt(Instant.parse("2026-11-04T10:00:03Z"));
        Message reply = new Message(); reply.setId(20L); reply.setSenderId(2L); reply.setConversationId(5L); reply.setBody("Reply");
        Message older = new Message(); older.setId(19L); older.setSenderId(2L); older.setConversationId(5L);
        when(messages.repliesTo(eq(5L), eq(10L), eq(1L), eq(0L), isNull(), any())).thenReturn(List.of(reply, older));
        var result = controller.details(1L, 10L, null, 1);
        assertEquals("2026-11-04T10:00:01Z", result.deliveredAt());
        assertEquals("2026-11-04T10:00:03Z", result.readAt());
        assertEquals(1, result.replies().items().size()); assertEquals(20L, result.replies().nextCursor());
    }
    @Test void deliveredButUnreadReturnsOnlyDeliveredTime() {
        message.setDeliveredAt(Instant.parse("2026-11-04T10:00:01Z"));
        when(receipts.statuses(anyLong(), anyCollection(), isNull(), anyMap())).thenReturn(Map.of(10L, "DELIVERED"));
        var result = controller.details(1L, 10L, null, 20);
        assertEquals("2026-11-04T10:00:01Z", result.deliveredAt());
        assertNull(result.readAt());
        assertEquals("DELIVERED", result.status());
    }
    @Test void sentOnlyMessageReturnsNullTimesNot404() {
        when(receipts.statuses(anyLong(), anyCollection(), isNull(), anyMap())).thenReturn(Map.of());
        message.setDeliveredAt(Instant.parse("2026-11-04T10:00:01Z")); // engelli/askidaki alici: sizmaz
        var result = controller.details(1L, 10L, null, 20);
        assertEquals("SENT", result.status());
        assertNull(result.deliveredAt()); assertNull(result.readAt());
        assertTrue(result.replies().items().isEmpty()); assertNull(result.replies().nextCursor());
    }
    @Test void deletedMessageAndUnknownMessageAre404() {
        message.setDeletedAt(Instant.parse("2026-11-04T11:00:00Z"));
        assertEquals(404, assertThrows(ApiException.class, () -> controller.details(1L, 10L, null, 20)).status().value());
        assertEquals(404, assertThrows(ApiException.class, () -> controller.details(1L, 99L, null, 20)).status().value());
    }
}
