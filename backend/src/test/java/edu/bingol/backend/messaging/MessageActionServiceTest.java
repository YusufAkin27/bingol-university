package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
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
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageEvent;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReactionSummary;
import edu.bingol.backend.messaging.room.RoomModeration;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;

class MessageActionServiceTest {

    private static final Long ME = 1L;
    private static final Long PEER = 2L;
    private static final Long CONV = 10L;
    private static final Long MSG = 100L;
    private static final String THUMBS = "👍";

    private final MessageRepository messages = mock(MessageRepository.class);
    private final MessageReactionRepository reactions = mock(MessageReactionRepository.class);
    private final ConversationRepository convs = mock(ConversationRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final ChatEventBus bus = mock(ChatEventBus.class);
    private final MessageCodec codec = mock(MessageCodec.class);
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final MessageViewAssembler assembler = new MessageViewAssembler(messages, reactions, codec);

    private MessageActionService service = build(15, 0);
    private Conversation conv;
    private Message msg;

    private MessageActionService build(long edit, long delete) {
        return new MessageActionService(messages, reactions, convs, members, users, blocks, bus, codec, assembler, jdbc,
                edit, delete, "");
    }

    @BeforeEach
    void setUp() {
        conv = new Conversation();
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
        member(ME, ConversationMember.Role.MEMBER);
        member(PEER, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(
                ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER),
                ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER)));
        for (Long id : List.of(ME, PEER, 3L)) {
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
            m.setBodyNonce(new byte[] {8});
            m.setKeyVersion(2);
            return null;
        }).when(codec).seal(any(Message.class), anyString());
        when(messages.applyEdit(anyLong(), any(), any(), any(), any())).thenReturn(1);
        when(messages.tombstone(anyLong(), any(), anyLong())).thenReturn(1);
    }

    private void member(Long uid, ConversationMember.Role role) {
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, uid))
                .thenReturn(Optional.of(ConversationMember.of(CONV, uid, role)));
    }

    private static ApiException fail(org.junit.jupiter.api.function.Executable e) {
        return assertThrows(ApiException.class, e);
    }

    // --- duzenleme ---

    @Test
    void ownerEditsWithinWindowAndPublishesEvent() {
        MessageView v = service.edit(ME, MSG, "  yeni metin ");

        assertEquals("yeni metin", v.text());
        assertTrue(v.edited());
        verify(codec).seal(msg, "yeni metin");
        verify(messages).applyEdit(eq(MSG), any(), any(), eq(2), any());
        ArgumentCaptor<Object> ev = ArgumentCaptor.forClass(Object.class);
        verify(bus).publish(eq("message-events"), anyCollection(), ev.capture());
        MessageEvent e = (MessageEvent) ev.getValue();
        assertEquals("edited", e.type());
        assertEquals("yeni metin", e.message().text());
    }

    @Test
    void editClearsLegacyPlaintextColumnWhenPresent() {
        when(codec.legacyColumnPresent()).thenReturn(true);

        service.edit(ME, MSG, "yeni");

        verify(jdbc).update(anyString(), eq(MSG));
    }

    @Test
    void sameTextEditIsNoOp() {
        MessageView v = service.edit(ME, MSG, "eski");

        assertFalse(v.edited());
        verify(messages, never()).applyEdit(anyLong(), any(), any(), any(), any());
        verify(bus, never()).publish(anyString(), anyCollection(), any());
    }

    @Test
    void editAfterWindowIs403() {
        msg.setCreatedAt(Instant.now().minus(Duration.ofMinutes(16)));

        ApiException e = fail(() -> service.edit(ME, MSG, "yeni"));

        assertEquals("MESSAGE_EDIT_EXPIRED", e.code());
        assertEquals(HttpStatus.FORBIDDEN, e.status());
        verify(messages, never()).applyEdit(anyLong(), any(), any(), any(), any());
    }

    @Test
    void editWindowIsConfigurable() {
        service = build(60, 0);
        msg.setCreatedAt(Instant.now().minus(Duration.ofMinutes(45)));

        assertEquals("yeni", service.edit(ME, MSG, "yeni").text());
    }

    @Test
    void cannotEditOthersMessage() {
        ApiException e = fail(() -> service.edit(PEER, MSG, "yeni"));

        assertEquals("MESSAGE_NOT_OWNER", e.code());
        assertEquals(HttpStatus.FORBIDDEN, e.status());
    }

    @Test
    void cannotEditDeletedMessage() {
        msg.setDeletedAt(Instant.now());

        assertEquals("MESSAGE_NOT_EDITABLE", fail(() -> service.edit(ME, MSG, "yeni")).code());
    }

    @Test
    void editRejectsEmptyAndTooLong() {
        assertEquals("EMPTY_MESSAGE", fail(() -> service.edit(ME, MSG, "   ")).code());
        assertEquals("MESSAGE_TOO_LONG", fail(() -> service.edit(ME, MSG, "a".repeat(2001))).code());
    }

    @Test
    void nonMemberGets404ForEveryAction() {
        for (org.junit.jupiter.api.function.Executable ex : List.<org.junit.jupiter.api.function.Executable>of(
                () -> service.edit(99L, MSG, "x"), () -> service.delete(99L, MSG),
                () -> service.react(99L, MSG, THUMBS), () -> service.unreact(99L, MSG))) {
            ApiException e = fail(ex);
            assertEquals(HttpStatus.NOT_FOUND, e.status());
            assertEquals("MESSAGE_NOT_FOUND", e.code());
        }
        verify(messages, never()).tombstone(anyLong(), any(), anyLong());
    }

    @Test
    void unknownMessageIs404() {
        when(messages.findById(555L)).thenReturn(Optional.empty());

        assertEquals("MESSAGE_NOT_FOUND", fail(() -> service.delete(ME, 555L)).code());
    }

    @Test
    void editInBlockedDirectIs403() {
        when(blocks.isBlocked(ME, PEER)).thenReturn(true);

        assertEquals("BLOCKED", fail(() -> service.edit(ME, MSG, "yeni")).code());
    }

    @Test
    void suspendedUserCannotEdit() {
        User u = new User();
        u.setId(ME);
        u.setStatus(edu.bingol.backend.user.UserStatus.SUSPENDED);
        when(users.findById(ME)).thenReturn(Optional.of(u));

        assertEquals("ACCOUNT_SUSPENDED", fail(() -> service.edit(ME, MSG, "yeni")).code());
    }

    // --- silme ---

    @Test
    void ownerDeletesForEveryoneAndTombstones() {
        service.delete(ME, MSG);

        verify(messages).tombstone(eq(MSG), any(), eq(ME));
        verify(reactions).removeAll(MSG);
        ArgumentCaptor<Object> ev = ArgumentCaptor.forClass(Object.class);
        verify(bus).publish(eq("message-events"), anyCollection(), ev.capture());
        assertEquals("deleted", ((MessageEvent) ev.getValue()).type());
    }

    @Test
    void deleteClearsLegacyPlaintextColumn() {
        when(codec.legacyColumnPresent()).thenReturn(true);

        service.delete(ME, MSG);

        verify(jdbc).update(anyString(), eq(MSG));
    }

    @Test
    void deleteIsIdempotent() {
        msg.setDeletedAt(Instant.now());

        service.delete(ME, MSG);

        verify(messages, never()).tombstone(anyLong(), any(), anyLong());
        verify(bus, never()).publish(anyString(), anyCollection(), any());
    }

    @Test
    void memberCannotDeleteOthersMessageInDirect() {
        assertEquals("MESSAGE_DELETE_FORBIDDEN", fail(() -> service.delete(PEER, MSG)).code());
    }

    @Test
    void groupAdminDeletesAnyMessageEvenAfterWindow() {
        service = build(15, 5);
        conv.setType(Conversation.Type.GROUP);
        msg.setCreatedAt(Instant.now().minus(Duration.ofHours(3)));
        member(3L, ConversationMember.Role.ADMIN);
        ConversationMember adminM = ConversationMember.of(CONV, 3L, ConversationMember.Role.ADMIN);
        adminM.setJoinedAt(Instant.now().minus(Duration.ofDays(1)));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, 3L)).thenReturn(Optional.of(adminM));

        service.delete(3L, MSG);

        verify(messages).tombstone(eq(MSG), any(), eq(3L));
    }

    @Test
    void groupMemberCannotDeleteOthers() {
        conv.setType(Conversation.Type.GROUP);
        ConversationMember m = ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER);
        m.setJoinedAt(Instant.now().minus(Duration.ofDays(1)));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, PEER)).thenReturn(Optional.of(m));
        ConversationMember me = ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER);
        me.setJoinedAt(Instant.now().minus(Duration.ofDays(1)));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, ME)).thenReturn(Optional.of(me));

        assertEquals("MESSAGE_DELETE_FORBIDDEN", fail(() -> service.delete(PEER, MSG)).code());
    }

    @Test
    void deleteWindowAppliesToSenderWhenConfigured() {
        service = build(15, 10);
        msg.setCreatedAt(Instant.now().minus(Duration.ofMinutes(11)));

        assertEquals("MESSAGE_DELETE_EXPIRED", fail(() -> service.delete(ME, MSG)).code());
        verify(messages, never()).tombstone(anyLong(), any(), anyLong());
    }

    @Test
    void noDeleteWindowByDefaultMeansUnlimited() {
        msg.setCreatedAt(Instant.now().minus(Duration.ofDays(30)));

        service.delete(ME, MSG);

        verify(messages).tombstone(eq(MSG), any(), eq(ME));
    }

    private void joinedLongAgo(Long uid) {
        ConversationMember m = ConversationMember.of(CONV, uid, ConversationMember.Role.MEMBER);
        m.setJoinedAt(Instant.now().minus(Duration.ofDays(1)));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, uid)).thenReturn(Optional.of(m));
    }

    @Test
    void roomModeratorDeletesOthersMessageInRoomEvenAfterWindow() {
        service = build(15, 5);
        RoomModeration moderation = mock(RoomModeration.class);
        service.setRoomModeration(moderation);
        conv.setType(Conversation.Type.GROUP);
        msg.setSenderId(PEER);
        joinedLongAgo(ME);
        when(moderation.canModerate(CONV, ME)).thenReturn(true);

        service.delete(ME, MSG);

        verify(messages).tombstone(eq(MSG), any(), eq(ME));
    }

    @Test
    void nonModeratorMemberCannotDeleteOthersMessageInRoom() {
        RoomModeration moderation = mock(RoomModeration.class);
        service.setRoomModeration(moderation);
        conv.setType(Conversation.Type.GROUP);
        msg.setSenderId(PEER);
        joinedLongAgo(ME);
        when(moderation.canModerate(CONV, ME)).thenReturn(false);

        assertEquals("MESSAGE_DELETE_FORBIDDEN", fail(() -> service.delete(ME, MSG)).code());
        verify(messages, never()).tombstone(anyLong(), any(), anyLong());
    }

    // --- tepkiler ---

    @Test
    void reactStoresAndReturnsCounts() {
        when(reactions.counts(List.of(MSG))).thenReturn(List.<Object[]>of(new Object[] {MSG, THUMBS, 2L}));
        MessageReaction mine = new MessageReaction();
        mine.setMessageId(MSG);
        mine.setUserId(ME);
        mine.setEmoji(THUMBS);
        when(reactions.mine(ME, List.of(MSG))).thenReturn(List.of(mine));

        ReactionSummary s = service.react(ME, MSG, THUMBS);

        verify(reactions).upsert(eq(MSG), eq(ME), eq(THUMBS), any());
        assertEquals(2L, s.reactions().get(0).count());
        assertEquals(THUMBS, s.myReaction());
        ArgumentCaptor<Object> ev = ArgumentCaptor.forClass(Object.class);
        verify(bus).publish(eq("message-events"), anyCollection(), ev.capture());
        MessageEvent e = (MessageEvent) ev.getValue();
        assertEquals("reaction", e.type());
        assertEquals(THUMBS, e.emoji());
    }

    @Test
    void reactionOutsideAllowedListIs400() {
        ApiException e = fail(() -> service.react(ME, MSG, "💩"));

        assertEquals("REACTION_NOT_ALLOWED", e.code());
        assertEquals(HttpStatus.BAD_REQUEST, e.status());
        verify(reactions, never()).upsert(anyLong(), anyLong(), anyString(), any());
    }

    @Test
    void variationSelectorDifferenceIsIgnored() {
        service.react(ME, MSG, "❤"); // izinli liste ❤️ icerir

        verify(reactions).upsert(eq(MSG), eq(ME), eq("❤"), any());
    }

    @Test
    void allowedListIsConfigurable() {
        service = new MessageActionService(messages, reactions, convs, members, users, blocks, bus, codec, assembler, jdbc,
                15, 0, "💩, x");

        service.react(ME, MSG, "💩");

        verify(reactions).upsert(eq(MSG), eq(ME), eq("💩"), any());
        assertEquals(2, service.allowedReactions().size());
    }

    @Test
    void cannotReactToDeletedOrHiddenMessage() {
        msg.setDeletedAt(Instant.now());
        assertEquals("MESSAGE_NOT_FOUND", fail(() -> service.react(ME, MSG, THUMBS)).code());
        msg.setDeletedAt(null);
        msg.setHiddenAt(Instant.now());
        assertEquals("MESSAGE_NOT_FOUND", fail(() -> service.react(ME, MSG, THUMBS)).code());
        verify(reactions, never()).upsert(anyLong(), anyLong(), anyString(), any());
    }

    @Test
    void reactInBlockedDirectIs403() {
        when(blocks.isBlocked(ME, PEER)).thenReturn(true);

        assertEquals("BLOCKED", fail(() -> service.react(ME, MSG, THUMBS)).code());
    }

    @Test
    void unreactRemovesAndPublishesOnlyWhenSomethingChanged() {
        when(reactions.remove(MSG, ME)).thenReturn(1);
        assertNotNull(service.unreact(ME, MSG));
        verify(bus).publish(eq("message-events"), anyCollection(), any());

        org.mockito.Mockito.clearInvocations(bus);
        when(reactions.remove(MSG, ME)).thenReturn(0);
        service.unreact(ME, MSG);
        verify(bus, never()).publish(anyString(), anyCollection(), any());
    }

    @Test
    void groupJoinedAfterMessageGets404() {
        conv.setType(Conversation.Type.GROUP);
        ConversationMember late = ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER);
        late.setJoinedAt(Instant.now());
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, PEER)).thenReturn(Optional.of(late));

        assertEquals("MESSAGE_NOT_FOUND", fail(() -> service.react(PEER, MSG, THUMBS)).code());
    }
}
