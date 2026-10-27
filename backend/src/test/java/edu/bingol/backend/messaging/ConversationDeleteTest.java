package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.messaging.room.ChatRoomLink;
import edu.bingol.backend.messaging.room.ChatRoomLinkRepository;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** "Sohbeti sil": birebirde imlec + gizleme, grupta ayrilma + gizleme, odada 400, idempotency, 404. */
class ConversationDeleteTest {

    final ConversationRepository convs = mock(ConversationRepository.class);
    final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    final ConversationService service = new ConversationService(convs, members, mock(MessageRepository.class),
            mock(UserRepository.class), mock(BlockService.class), mock(MessageCodec.class));
    final ChatRoomLinkRepository links = mock(ChatRoomLinkRepository.class);

    Conversation conv;
    ConversationMember me;

    @BeforeEach
    void setUp() {
        service.setRoomLinks(links);
        conv = new Conversation();
        conv.setId(5L);
        conv.setType(Conversation.Type.DIRECT);
        conv.setLastMessageId(77L);
        when(convs.findById(5L)).thenReturn(Optional.of(conv));
        me = ConversationMember.of(5L, 1L, ConversationMember.Role.MEMBER);
        me.setMutedUntil(Instant.now().plusSeconds(3600));
        me.setArchivedAt(Instant.now());
        me.setArchiveSticky(true);
        when(members.findByConversationIdAndUserId(5L, 1L)).thenReturn(Optional.of(me));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 1L)).thenAnswer(inv ->
                Optional.ofNullable(me.getLeftAt() == null ? me : null));
        when(links.findByConversationIdIn(List.of(5L))).thenReturn(List.of());
    }

    @Test
    void directClearsUpToLastMessageHidesAndResetsPrefsOnlyForCaller() {
        service.delete(1L, 5L);

        assertEquals(77L, me.getClearedUpToMessageId());
        assertNotNull(me.getHiddenAt());
        assertNull(me.getMutedUntil());
        assertNull(me.getArchivedAt());
        assertTrue(!me.isArchiveSticky());
        assertNull(me.getLeftAt()); // uyelik surer: yeni mesaj gelebilir
        assertEquals(77L, conv.getLastMessageId()); // sohbet/karsi taraf degismez
    }

    @Test
    void deleteIsIdempotentAndNeverMovesClearBackward() {
        service.delete(1L, 5L);
        Instant first = me.getHiddenAt();
        conv.setLastMessageId(70L); // olmayacak ama geri gitmemeli
        service.delete(1L, 5L);
        assertEquals(77L, me.getClearedUpToMessageId());
        assertEquals(first, me.getHiddenAt());
    }

    @Test
    void nonMemberGets404() {
        assertEquals(404, assertThrows(ApiException.class, () -> service.delete(9L, 5L)).status().value());
    }

    @Test
    void roomsCannotBeDeleted() {
        conv.setType(Conversation.Type.GROUP);
        when(links.findByConversationIdIn(List.of(5L))).thenReturn(List.of(new ChatRoomLink()));
        ApiException e = assertThrows(ApiException.class, () -> service.delete(1L, 5L));
        assertEquals("CONVERSATION_NOT_DELETABLE", e.code());
        assertEquals(400, e.status().value());
    }

    @Test
    void userGroupLeavesAndIsHidden() {
        conv.setType(Conversation.Type.GROUP);
        me.setRole(ConversationMember.Role.ADMIN);
        ConversationMember other = ConversationMember.of(5L, 2L, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(5L)).thenReturn(List.of(other));

        service.delete(1L, 5L);

        assertNotNull(me.getLeftAt());
        assertNotNull(me.getHiddenAt());
        assertEquals(ConversationMember.Role.ADMIN, other.getRole()); // son yonetici devri leave mantigiyla
        service.delete(1L, 5L); // zaten ayrilmis: yine 204 (istisna yok)
    }
}
