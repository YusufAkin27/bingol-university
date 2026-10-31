package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationDetail;
import edu.bingol.backend.messaging.dto.MessagingDtos.ConversationRemovedEvent;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.room.ChatRoomLink;
import edu.bingol.backend.messaging.room.ChatRoomLinkRepository;
import edu.bingol.backend.messaging.room.RoomKind;
import edu.bingol.backend.messaging.room.RoomModeration;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.profile.privacy.AvatarVisibility;
import edu.bingol.backend.profile.privacy.AvatarVisibility.Field;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.EnumMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * W1-D: yer tutucu turleri (T-034), cikis sonrasi yeniden ekleme yasagi ve ek limit (T-025), avatar gizliligi (T-027),
 * golge engel (T-028), conversation-removed olayi (T-031), canModerate (T-032).
 */
class MessagingPrivacyW1dTest {

    final ConversationRepository convs = mock(ConversationRepository.class);
    final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    final MessageRepository messages = mock(MessageRepository.class);
    final UserRepository users = mock(UserRepository.class);
    final BlockService blocks = mock(BlockService.class);
    final ConversationAddBanRepository bans = mock(ConversationAddBanRepository.class);
    final ChatEventBus bus = mock(ChatEventBus.class);
    final RateLimiter limiter = mock(RateLimiter.class);
    final ConversationService service = new ConversationService(convs, members, messages, users, blocks,
            mock(MessageCodec.class));

    static User user(long id) {
        User u = new User();
        u.setId(id);
        u.setEmailVerified(true);
        u.setDisplayName("U" + id);
        u.setAvatarUrl("/files/avatars/a" + id + ".jpg");
        return u;
    }

    static Conversation conv(long id, Conversation.Type type) {
        Conversation c = new Conversation();
        c.setId(id);
        c.setType(type);
        c.setCreatedBy(1L);
        return c;
    }

    @BeforeEach
    void setUp() {
        service.setBus(bus);
        service.setAddBans(bans);
        service.setLimiter(limiter);
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(users.findAllById(any())).thenAnswer(inv -> {
            List<User> out = new ArrayList<>();
            for (Object id : (Iterable<?>) inv.getArgument(0)) {
                out.add(user((Long) id));
            }
            return out;
        });
        when(bans.bannedUsers(anyLong(), anyCollection())).thenReturn(List.of());
    }

    // ------------------------------------------------------------------ T-034 yer tutucu turleri

    @Test
    void placeholderKindIsBlockedUnreadableOrNull() throws Exception {
        Message ok = new Message();
        ok.setId(1L);
        ok.setConversationId(5L);
        ok.setSenderId(2L);
        ok.setBody("merhaba");
        ok.setCreatedAt(Instant.now());
        assertNull(MessageView.of(ok).placeholderKind());

        MessageView blocked = MessageView.of(ok, true);
        assertEquals("BLOCKED", blocked.placeholderKind());
        assertEquals(MessagingDtos.BLOCKED_TEXT, blocked.text()); // eski istemci Turkce metni gorur
        assertTrue(blocked.removed());

        Message unreadable = new Message();
        unreadable.setId(2L);
        unreadable.setConversationId(5L);
        unreadable.setSenderId(2L);
        unreadable.setCreatedAt(Instant.now());
        MessageView u = MessageView.of(unreadable);
        assertEquals("UNREADABLE", u.placeholderKind());
        assertEquals(MessagingDtos.UNREADABLE_TEXT, u.text());

        Message deleted = new Message();
        deleted.setId(3L);
        deleted.setConversationId(5L);
        deleted.setSenderId(2L);
        deleted.setBody("x");
        deleted.setDeletedAt(Instant.now());
        deleted.setCreatedAt(Instant.now());
        assertNull(MessageView.of(deleted, true).placeholderKind()); // silinmis/gizlenmis yer tutucu degil
    }

    @Test
    void placeholderKindSurvivesWithersAndSerializesOnlyWhenSet() throws Exception {
        Message m = new Message();
        m.setId(2L);
        m.setConversationId(5L);
        m.setSenderId(2L);
        m.setCreatedAt(Instant.now());
        MessageView v = MessageView.of(m).withStatus("SENT").withSenderName("Ali").withExtras(null, List.of(), null)
                .withAttachments(List.of());
        assertEquals("UNREADABLE", v.placeholderKind());

        ObjectMapper om = new ObjectMapper();
        assertTrue(om.writeValueAsString(v).contains("\"placeholderKind\":\"UNREADABLE\""));
        m.setBody("normal");
        assertFalse(om.writeValueAsString(MessageView.of(m)).contains("placeholderKind")); // eski surum sozlesmesi: alan yok
    }

    @Test
    void replyPreviewCarriesPlaceholderKind() {
        MessageRepository msgRepo = mock(MessageRepository.class);
        MessageReactionRepository reactions = mock(MessageReactionRepository.class);
        MessageCodec codec = mock(MessageCodec.class);
        when(reactions.counts(any())).thenReturn(List.of());
        when(reactions.mine(anyLong(), any())).thenReturn(List.of());
        MessageViewAssembler assembler = new MessageViewAssembler(msgRepo, reactions, codec);

        Message parentBlocked = msg(10L, 3L, "gizli");
        Message parentUnreadable = msg(11L, 4L, null);
        Message parentOk = msg(12L, 4L, "okunur");
        when(msgRepo.findAllById(any())).thenReturn(List.of(parentBlocked, parentUnreadable, parentOk));
        Message r1 = reply(20L, 10L);
        Message r2 = reply(21L, 11L);
        Message r3 = reply(22L, 12L);

        List<MessageView> out = assembler.assemble(1L, List.of(r1, r2, r3), Set.of(3L), null);

        // engelli gonderenin mesajina yanit: onizleme BLOCKED turu; okunmayan UNREADABLE; normal olanda tur yok
        assertEquals("BLOCKED", out.get(0).replyTo().placeholderKind());
        assertEquals(MessagingDtos.BLOCKED_TEXT, out.get(0).replyTo().text());
        assertEquals("UNREADABLE", out.get(1).replyTo().placeholderKind());
        assertEquals(MessagingDtos.UNREADABLE_TEXT, out.get(1).replyTo().text());
        assertNull(out.get(2).replyTo().placeholderKind());
        assertEquals("okunur", out.get(2).replyTo().text());
    }

    private static Message msg(long id, long sender, String body) {
        Message m = new Message();
        m.setId(id);
        m.setConversationId(5L);
        m.setSenderId(sender);
        m.setBody(body);
        m.setCreatedAt(Instant.now().minusSeconds(100));
        return m;
    }

    private static Message reply(long id, long to) {
        Message m = msg(id, 2L, "yanit");
        m.setReplyToMessageId(to);
        m.setCreatedAt(Instant.now());
        return m;
    }

    // ------------------------------------------------------------------ T-025 yeniden ekleme yasagi

    private void groupWithAdmin1(long cid) {
        Conversation g = conv(cid, Conversation.Type.GROUP);
        when(convs.findById(cid)).thenReturn(Optional.of(g));
        ConversationMember admin = ConversationMember.of(cid, 1L, ConversationMember.Role.ADMIN);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(cid, 1L)).thenReturn(Optional.of(admin));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(cid)).thenReturn(List.of(admin));
        when(members.findByConversationIdInAndLeftAtIsNull(any())).thenReturn(List.of(admin));
    }

    @Test
    void leavingRecordsBanForTheAdderAndBannedAdderCannotReAdd() {
        // U3, 1 tarafindan eklenmisti ve kendi cikti
        Conversation g = conv(5L, Conversation.Type.GROUP);
        when(convs.findById(5L)).thenReturn(Optional.of(g));
        ConversationMember self = ConversationMember.of(5L, 3L, ConversationMember.Role.MEMBER);
        self.setAddedBy(1L);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 3L)).thenReturn(Optional.of(self));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(5L)).thenReturn(List.of());

        service.leave(3L, 5L);

        ArgumentCaptor<ConversationAddBan> ban = ArgumentCaptor.forClass(ConversationAddBan.class);
        verify(bans).save(ban.capture());
        assertEquals(3L, ban.getValue().getUserId());
        assertEquals(1L, ban.getValue().getAdderId());

        // 1 tekrar eklemeyi dener: yasakli kisi SESSIZCE atlanir (hata yok, uye eklenmez)
        org.mockito.Mockito.clearInvocations(members);
        groupWithAdmin1(6L);
        when(bans.bannedUsers(eq(1L), anyCollection())).thenReturn(List.of(3L));
        when(members.countByConversationIdAndLeftAtIsNull(6L)).thenReturn(1L);

        service.addMembers(1L, 6L, List.of(3L, 4L));

        ArgumentCaptor<ConversationMember> saved = ArgumentCaptor.forClass(ConversationMember.class);
        verify(members).save(saved.capture());
        assertEquals(4L, saved.getValue().getUserId()); // yalniz yasaksiz olan
        assertEquals(1L, saved.getValue().getAddedBy());
    }

    @Test
    void adminRemovalAlsoRecordsBanForOriginalAdder() {
        groupWithAdmin1(5L);
        ConversationMember target = ConversationMember.of(5L, 3L, ConversationMember.Role.MEMBER);
        target.setAddedBy(2L); // baska biri eklemisti
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 3L)).thenReturn(Optional.of(target));

        service.removeMember(1L, 5L, 3L);

        ArgumentCaptor<ConversationAddBan> ban = ArgumentCaptor.forClass(ConversationAddBan.class);
        verify(bans).save(ban.capture());
        assertEquals(2L, ban.getValue().getAdderId());
        assertEquals(3L, ban.getValue().getUserId());
    }

    @Test
    void memberWithoutAdderOrSelfAddedLeavesNoBan() {
        Conversation g = conv(5L, Conversation.Type.GROUP);
        when(convs.findById(5L)).thenReturn(Optional.of(g));
        ConversationMember creator = ConversationMember.of(5L, 1L, ConversationMember.Role.ADMIN); // addedBy null
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 1L)).thenReturn(Optional.of(creator));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(5L)).thenReturn(List.of());

        service.leave(1L, 5L);

        verify(bans, never()).save(any());
    }

    @Test
    void newGroupSilentlySkipsBannedAndAddedByIsRecorded() {
        when(bans.bannedUsers(eq(1L), anyCollection())).thenReturn(List.of(3L));
        when(convs.save(any(Conversation.class))).thenAnswer(inv -> {
            Conversation c = inv.getArgument(0);
            c.setId(9L);
            return c;
        });
        List<ConversationMember> saved = new ArrayList<>();
        when(members.save(any(ConversationMember.class))).thenAnswer(inv -> {
            saved.add(inv.getArgument(0));
            return inv.getArgument(0);
        });

        service.createGroup(1L, "Grup", List.of(2L, 3L));

        assertEquals(List.of(1L, 2L), saved.stream().map(ConversationMember::getUserId).toList());
        assertEquals(1L, saved.get(1).getAddedBy());
        assertNull(saved.get(0).getAddedBy());
    }

    @Test
    void newDirectConversationAndNewGroupAreLimitedPerDay() {
        when(convs.insertDirect(eq("1:2"), eq(1L), any())).thenReturn(1);
        when(convs.findByDirectKey("1:2")).thenReturn(Optional.of(conv(7L, Conversation.Type.DIRECT)));

        service.openDirect(1L, 2L);
        verify(limiter).check("conv:newpeer:1", 10, Duration.ofDays(1));

        when(convs.save(any(Conversation.class))).thenAnswer(inv -> {
            Conversation c = inv.getArgument(0);
            c.setId(9L);
            return c;
        });
        service.createGroup(1L, "Grup", List.of(2L));
        verify(limiter).check("conv:newgroup:1", 10, Duration.ofDays(1));
    }

    @Test
    void reopeningExistingDirectConversationDoesNotCountAsNewPeer() {
        when(convs.insertDirect(eq("1:2"), eq(1L), any())).thenReturn(0);
        when(convs.findByDirectKey("1:2")).thenReturn(Optional.of(conv(7L, Conversation.Type.DIRECT)));

        service.openDirect(1L, 2L);

        verify(limiter, never()).check(eq("conv:newpeer:1"), anyInt(), any());
    }

    @Test
    void exceededNewConversationLimitStopsCreation() {
        when(convs.insertDirect(eq("1:2"), eq(1L), any())).thenReturn(1);
        when(convs.findByDirectKey("1:2")).thenReturn(Optional.of(conv(7L, Conversation.Type.DIRECT)));
        org.mockito.Mockito.doThrow(new ApiException(org.springframework.http.HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "x"))
                .when(limiter).check(eq("conv:newpeer:1"), anyInt(), any());

        assertEquals("RATE_LIMITED", assertThrows(ApiException.class, () -> service.openDirect(1L, 2L)).code());
        verify(members, never()).save(any()); // uyelikler yazilmadi (islem geri alinir)
    }

    // ------------------------------------------------------------------ T-028 golge engel

    @Test
    void personWhoBlockedMeIsSilentlySkippedInGroupWithNoErrorAndNoFlag() {
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of(3L)); // 3 beni engellemis
        when(blocks.hasBlocked(1L, 3L)).thenReturn(false);
        when(convs.save(any(Conversation.class))).thenAnswer(inv -> {
            Conversation c = inv.getArgument(0);
            c.setId(9L);
            return c;
        });
        List<ConversationMember> saved = new ArrayList<>();
        when(members.save(any(ConversationMember.class))).thenAnswer(inv -> {
            saved.add(inv.getArgument(0));
            return inv.getArgument(0);
        });

        service.createGroup(1L, "Grup", List.of(2L, 3L)); // 403 BLOCKED YOK

        assertEquals(List.of(1L, 2L), saved.stream().map(ConversationMember::getUserId).toList());
    }

    @Test
    void personWhoBlockedMeIsSilentlySkippedWhenAddingMembers() {
        groupWithAdmin1(5L);
        when(blocks.hiddenFrom(1L)).thenReturn(Set.of(3L));
        when(blocks.hasBlocked(1L, 3L)).thenReturn(false);
        when(members.countByConversationIdAndLeftAtIsNull(5L)).thenReturn(1L);

        service.addMembers(1L, 5L, List.of(3L)); // hata yok

        verify(members, never()).save(any());
    }

    private void directWithPeer2(Set<Long> related, boolean iBlocked) {
        Conversation d = conv(5L, Conversation.Type.DIRECT);
        when(convs.findById(5L)).thenReturn(Optional.of(d));
        ConversationMember me = ConversationMember.of(5L, 1L, ConversationMember.Role.MEMBER);
        ConversationMember peer = ConversationMember.of(5L, 2L, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 1L)).thenReturn(Optional.of(me));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(5L)).thenReturn(List.of(me, peer));
        when(members.findByConversationIdInAndLeftAtIsNull(any())).thenReturn(List.of(me, peer));
        when(blocks.hiddenFrom(1L)).thenReturn(related);
        when(blocks.hasBlocked(1L, 2L)).thenReturn(iBlocked);
    }

    @Test
    void blockedFlagIsTrueOnlyForTheBlocker() {
        directWithPeer2(Set.of(2L), true);
        assertTrue(service.detail(1L, 5L).conversation().blocked()); // ben engelledim

        directWithPeer2(Set.of(2L), false); // o beni engellemis: ben (engellenen) false gorurum
        assertFalse(service.detail(1L, 5L).conversation().blocked());
        assertEquals("U2", service.detail(1L, 5L).conversation().peer().displayName());
    }

    // ------------------------------------------------------------------ T-027 avatar gizliligi (fail-closed)

    private AvatarVisibility visibility(Set<Long> avatarOk) {
        AvatarVisibility v = mock(AvatarVisibility.class);
        when(v.visibleOwners(anyLong(), anyCollection(), anyCollection())).thenAnswer(inv -> {
            Map<Field, Set<Long>> out = new EnumMap<>(Field.class);
            for (Object f : (Collection<?>) inv.getArgument(2)) {
                Field field = (Field) f;
                out.put(field, field == Field.AVATAR ? new HashSet<>(avatarOk) : new HashSet<>((Collection<Long>) inv.getArgument(1)));
            }
            return out;
        });
        return v;
    }

    @Test
    void onlyMeAvatarIsNullInPeerAndMembers() {
        directWithPeer2(Set.of(), false);
        service.setVisibility(visibility(Set.of(1L))); // 2'nin avatari bana kapali, kendi avatarim acik

        ConversationDetail d = service.detail(1L, 5L);

        assertNull(d.conversation().peer().avatarUrl());
        assertEquals("U2", d.conversation().peer().displayName());
        assertNull(d.members().stream().filter(m -> m.userId() == 2L).findFirst().orElseThrow().avatarUrl());
        assertNotNull(d.members().stream().filter(m -> m.userId() == 1L).findFirst().orElseThrow().avatarUrl());
    }

    @Test
    void visibleAvatarIsKeptAndMissingDecisionIsFailClosed() {
        directWithPeer2(Set.of(), false);
        service.setVisibility(visibility(Set.of(1L, 2L)));
        assertNotNull(service.detail(1L, 5L).conversation().peer().avatarUrl());

        ConversationService noVisibility = new ConversationService(convs, members, messages, users, blocks,
                mock(MessageCodec.class));
        ConversationDetail d = noVisibility.detail(1L, 5L); // gizlilik karari yok: avatar GONDERILMEZ
        assertNull(d.conversation().peer().avatarUrl());
        assertTrue(d.members().stream().allMatch(m -> m.avatarUrl() == null));
    }

    // ------------------------------------------------------------------ T-031 conversation-removed

    @Test
    void removedMemberAndLeavingUserGetConversationRemovedEvent() {
        groupWithAdmin1(5L);
        ConversationMember target = ConversationMember.of(5L, 3L, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 3L)).thenReturn(Optional.of(target));

        service.removeMember(1L, 5L, 3L);

        ArgumentCaptor<Object> ev = ArgumentCaptor.forClass(Object.class);
        verify(bus).publish(eq("message-events"), eq(List.of(3L)), ev.capture());
        ConversationRemovedEvent e = (ConversationRemovedEvent) ev.getValue();
        assertEquals("conversation-removed", e.type());
        assertEquals(5L, e.conversationId());

        // kendi ayrilmasi: kullanicinin DIGER cihazlari da duser
        org.mockito.Mockito.clearInvocations(bus);
        ConversationMember self = ConversationMember.of(5L, 4L, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(5L, 4L)).thenReturn(Optional.of(self));
        service.leave(4L, 5L);
        verify(bus).publish(eq("message-events"), eq(List.of(4L)), any(ConversationRemovedEvent.class));
    }

    // ------------------------------------------------------------------ T-032 canModerate

    @Test
    void canModerateFollowsGroupAdminAndRoomModerationAndNeverDirect() {
        // kullanici grubu: yonetici true, uye false
        groupWithAdmin1(5L);
        assertTrue(service.detail(1L, 5L).conversation().canModerate());

        Conversation g = conv(6L, Conversation.Type.GROUP);
        when(convs.findById(6L)).thenReturn(Optional.of(g));
        ConversationMember plain = ConversationMember.of(6L, 1L, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(6L, 1L)).thenReturn(Optional.of(plain));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(6L)).thenReturn(List.of(plain));
        when(members.findByConversationIdInAndLeftAtIsNull(any())).thenReturn(List.of(plain));
        assertFalse(service.detail(1L, 6L).conversation().canModerate());

        // kulup odasi: admin rolu yok ama oda moderatoru
        ChatRoomLink link = new ChatRoomLink();
        link.setConversationId(6L);
        link.setKind(RoomKind.COMMUNITY);
        link.setRefId(77L);
        ChatRoomLinkRepository links = mock(ChatRoomLinkRepository.class);
        when(links.findByConversationIdIn(any())).thenReturn(List.of(link));
        service.setRoomLinks(links);
        RoomModeration moderation = mock(RoomModeration.class);
        service.setRoomModeration(moderation);
        when(moderation.canModerate(6L, 1L)).thenReturn(true);
        ConversationView_assert(service.detail(1L, 6L), true);
        when(moderation.canModerate(6L, 1L)).thenReturn(false);
        ConversationView_assert(service.detail(1L, 6L), false);

        // birebir her zaman false
        directWithPeer2(Set.of(), false);
        assertFalse(service.detail(1L, 5L).conversation().canModerate());
    }

    private static void ConversationView_assert(ConversationDetail d, boolean expected) {
        assertEquals(expected, d.conversation().canModerate());
        assertEquals("CLUB", d.conversation().type());
    }

}
