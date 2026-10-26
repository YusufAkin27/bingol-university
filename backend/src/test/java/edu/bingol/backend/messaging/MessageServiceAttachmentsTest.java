package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.media.AttachmentView;
import edu.bingol.backend.messaging.media.MessageAttachmentService;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.messaging.ws.PresenceService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.PlatformTransactionManager;

/** T8: mesaj gonderiminde ek (attachmentIds) baglama ve gorunum davranisi. */
class MessageServiceAttachmentsTest {

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
    private final MessageCodec codec = mock(MessageCodec.class);
    private final MessageAttachmentService attachments = mock(MessageAttachmentService.class);
    private final MessageService service = new MessageService(convs, members, messages, users, blocks, limiter, bus,
            mock(PresenceService.class), mock(NotificationService.class), mock(ReportService.class),
            mock(PlatformTransactionManager.class), codec, false);

    @BeforeEach
    void setUp() {
        service.setAttachments(attachments);
        Conversation direct = new Conversation();
        direct.setId(CONV);
        direct.setType(Conversation.Type.DIRECT);
        when(convs.findById(CONV)).thenReturn(Optional.of(direct));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, ME))
                .thenReturn(Optional.of(ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER)));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(
                ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER),
                ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER)));
        User peer = new User();
        peer.setId(PEER);
        peer.setDisplayName("Ayse");
        User me = new User();
        me.setId(ME);
        me.setDisplayName("Ali");
        when(users.findById(PEER)).thenReturn(Optional.of(peer));
        when(users.findById(ME)).thenReturn(Optional.of(me));
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
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
    }

    @Test
    void imageOnlyMessageIsAcceptedAndAttachmentsAreClaimedAndDelivered() {
        when(attachments.precheck(ME, CONV, List.of(5L))).thenReturn(List.of(5L));
        AttachmentView av = new AttachmentView(5L, "IMAGE", 800, 600, 1234, "image/jpeg", false, "/u", "/t");
        when(attachments.viewsFor(List.of(100L))).thenReturn(Map.of(100L, List.of(av)));

        MessageService.SendResult r = service.send(ME, CONV, "", "c1", List.of(5L));

        assertTrue(r.created());
        MessageView v = r.message();
        assertEquals("", v.text());
        assertEquals(1, v.attachments().size());
        assertEquals(800, v.attachments().get(0).width());
        verify(attachments).claim(100L, ME, CONV, List.of(5L));
        // normal mesaj yolu: WebSocket olayi ek meta verisiyle yayinlanir
        verify(bus).publish(eq("messages"), any(), eq(v));
    }

    @Test
    void emptyTextWithoutAttachmentsIsStillRejected() {
        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, "  ", "c1", List.of()));
        assertEquals("EMPTY_MESSAGE", e.code());
        verify(messages, never()).saveAndFlush(any());
    }

    @Test
    void foreignOrUsedAttachmentIsRejectedBeforeAnythingIsSaved() {
        when(attachments.precheck(ME, CONV, List.of(9L)))
                .thenThrow(new ApiException(HttpStatus.BAD_REQUEST, "ATTACHMENT_INVALID", "x"));

        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, "merhaba", "c1", List.of(9L)));

        assertEquals("ATTACHMENT_INVALID", e.code());
        verify(messages, never()).saveAndFlush(any());
        verify(bus, never()).publish(anyString(), any(), any());
    }

    @Test
    void raceLostClaimAbortsMessageAndNothingIsPublished() {
        when(attachments.precheck(ME, CONV, List.of(5L))).thenReturn(List.of(5L));
        doThrow(new ApiException(HttpStatus.BAD_REQUEST, "ATTACHMENT_INVALID", "x"))
                .when(attachments).claim(anyLong(), anyLong(), anyLong(), any());

        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, "x", "c1", List.of(5L)));

        assertEquals("ATTACHMENT_INVALID", e.code());
        verify(bus, never()).publish(anyString(), any(), any());
    }

    @Test
    void textOnlySendDoesNotTouchAttachmentService() {
        MessageService.SendResult r = service.send(ME, CONV, "selam", "c1");

        assertTrue(r.created());
        assertFalse(r.message().removed());
        assertTrue(r.message().attachments().isEmpty());
        verify(attachments, never()).claim(anyLong(), anyLong(), anyLong(), any());
        verify(attachments, never()).precheck(anyLong(), anyLong(), any());
    }

    @Test
    void hiddenMessageDropsAttachmentsFromView() {
        AttachmentView av = new AttachmentView(5L, "IMAGE", 8, 6, 1, "image/jpeg", false, "/u", "/t");
        Message m = new Message();
        m.setId(1L);
        m.setConversationId(CONV);
        m.setSenderId(PEER);
        m.setClientId("c");
        m.setHiddenAt(java.time.Instant.now());
        MessageView v = MessageView.of(m).withAttachments(List.of(av));
        assertTrue(v.removed());
        assertTrue(v.attachments().isEmpty());
    }
}
