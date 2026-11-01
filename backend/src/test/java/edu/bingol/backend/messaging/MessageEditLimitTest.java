package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

/** FIX-P03 (A02#14): mesaj basina en cok 10 duzenleme; arsivleme + yazma birlikte. */
class MessageEditLimitTest {

    private static final Long ME = 1L;
    private static final Long PEER = 2L;
    private static final Long CONV = 10L;
    private static final Long MSG = 100L;

    private final MessageRepository messages = mock(MessageRepository.class);
    private final MessageReactionRepository reactions = mock(MessageReactionRepository.class);
    private final ConversationRepository convs = mock(ConversationRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final MessageCodec codec = mock(MessageCodec.class);
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final MessageActionService service = new MessageActionService(messages, reactions, convs, members, users,
            blocks, mock(ChatEventBus.class), codec, new MessageViewAssembler(messages, reactions, codec), jdbc, 0, 0, "");
    private Message msg;

    @BeforeEach
    void setUp() {
        Conversation conv = new Conversation();
        conv.setId(CONV);
        conv.setType(Conversation.Type.DIRECT);
        when(convs.findById(CONV)).thenReturn(Optional.of(conv));
        msg = new Message();
        msg.setId(MSG);
        msg.setConversationId(CONV);
        msg.setSenderId(ME);
        msg.setClientId("c1");
        msg.setBodyCiphertext(new byte[] {1});
        msg.setBodyNonce(new byte[] {2});
        msg.setKeyVersion(1);
        msg.setBody("eski");
        msg.setCreatedAt(Instant.now().minusSeconds(60));
        when(messages.findById(MSG)).thenReturn(Optional.of(msg));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, ME))
                .thenReturn(Optional.of(ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER)));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, PEER))
                .thenReturn(Optional.of(ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER)));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(
                ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER),
                ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER)));
        for (Long id : List.of(ME, PEER)) {
            User u = new User();
            u.setId(id);
            when(users.findById(id)).thenReturn(Optional.of(u));
        }
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(codec.open(any(Message.class))).thenAnswer(i -> i.getArgument(0));
        when(codec.openAll(any())).thenAnswer(i -> i.getArgument(0));
        org.mockito.Mockito.doAnswer(inv -> {
            Message m = inv.getArgument(0);
            m.setBody(inv.getArgument(1));
            m.setBodyCiphertext(new byte[] {9});
            return null;
        }).when(codec).seal(any(Message.class), anyString());
        when(messages.applyEdit(anyLong(), any(), any(), any(), any())).thenReturn(1);
    }

    @Test
    void eleventhEditIsRejectedWith409AndWritesNothing() {
        when(jdbc.queryForObject(anyString(), eq(Long.class), eq(MSG))).thenReturn(10L);

        ApiException e = assertThrows(ApiException.class, () -> service.edit(ME, MSG, "yeni"));

        assertEquals(409, e.status().value());
        assertEquals("MESSAGE_EDIT_LIMIT", e.code());
        verify(messages, never()).archiveRevision(anyLong());
        verify(messages, never()).applyEdit(anyLong(), any(), any(), any(), any());
    }

    @Test
    void tenthEditIsStillAllowed() {
        when(jdbc.queryForObject(anyString(), eq(Long.class), eq(MSG))).thenReturn(9L);

        service.edit(ME, MSG, "yeni");

        verify(messages).archiveRevision(MSG);
        verify(messages).applyEdit(eq(MSG), any(), any(), any(), any());
    }

    @Test
    void failedApplyRollsTheArchiveBackAndReports409() {
        when(messages.applyEdit(anyLong(), any(), any(), any(), any())).thenReturn(0);

        ApiException e = assertThrows(ApiException.class, () -> service.edit(ME, MSG, "yeni"));

        assertEquals("MESSAGE_NOT_EDITABLE", e.code());
    }
}
