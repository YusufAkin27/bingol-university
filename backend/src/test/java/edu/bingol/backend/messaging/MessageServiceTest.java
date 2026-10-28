package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.startsWith;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.doThrow;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.ReadReceipt;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.messaging.ws.PresenceService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.PlatformTransactionManager;

class MessageServiceTest {

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
    private final ReportService reports = mock(ReportService.class);
    private final MessageCodec codec = mock(MessageCodec.class);
    private final MessageReactionRepository reactions = mock(MessageReactionRepository.class);
    private final MessageViewAssembler assembler = new MessageViewAssembler(messages, reactions, codec);
    private final MessageService service = new MessageService(convs, members, messages, users, blocks, limiter, bus,
            presence, notifications, reports, mock(PlatformTransactionManager.class), codec, assembler, false);

    private Conversation direct;

    @BeforeEach
    void setUp() {
        direct = new Conversation();
        direct.setId(CONV);
        direct.setType(Conversation.Type.DIRECT);
        direct.setLastMessageId(50L);
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
        // Sifreleme MessageCodecTest'te sinanir; burada duz metin bellekte tasinir.
        org.mockito.Mockito.doAnswer(inv -> {
            ((Message) inv.getArgument(0)).setBody(inv.getArgument(1));
            return null;
        }).when(codec).seal(any(Message.class), anyString());
        when(codec.open(any(Message.class))).thenAnswer(inv -> inv.getArgument(0));
        when(codec.openAll(any())).thenAnswer(inv -> inv.getArgument(0));
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
    }

    @Test
    void nonParticipantCannotSend() {
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, 99L)).thenReturn(Optional.empty());

        ApiException e = assertThrows(ApiException.class, () -> service.send(99L, CONV, "selam", "c1"));

        assertEquals(HttpStatus.NOT_FOUND, e.status());
        verify(messages, never()).saveAndFlush(any());
        // yalniz ucuz kaba sinir (DB'den once) calisir; mesaj basina sinir ve yayin yok
        verify(limiter).check(startsWith("msg:all:"), anyInt(), any());
        verify(limiter, never()).check(startsWith("msg:user:"), anyInt(), any());
        verifyNoInteractions(bus);
    }

    @Test
    void blockedPairSendsWithoutErrorButMessageIsSuppressedAndNeverReachesPeer() {
        when(blocks.isBlocked(ME, PEER)).thenReturn(true);

        MessageService.SendResult r = service.send(ME, CONV, "selam", "c1");

        assertTrue(r.created()); // 201: hata yok
        ArgumentCaptor<Message> saved = ArgumentCaptor.forClass(Message.class);
        verify(messages).saveAndFlush(saved.capture());
        assertTrue(saved.getValue().isSuppressed()); // kalici bayrak
        // yalniz gondericiye (kendi cihazlari) yayin; karsi tarafa WS yok
        verify(bus).publish(org.mockito.ArgumentMatchers.eq("messages"), org.mockito.ArgumentMatchers.eq(List.of(ME)), any());
        verify(bus, never()).publish(org.mockito.ArgumentMatchers.eq("messages"),
                org.mockito.ArgumentMatchers.eq(List.of(PEER)), any());
        verifyNoInteractions(notifications); // push / uygulama ici bildirim yok
        // karsi tarafin listesi etkilenmez: gorunur son mesaj ilerlemez, golge bayragi acilir
        verify(convs).markShadowed(CONV);
        verify(convs, never()).touchLastVisible(anyLong(), anyLong());
        verify(members).advanceOwnSuppressed(CONV, ME, 100L);
        verify(members, never()).unhideOnMessage(anyLong());
        verify(members, never()).unarchiveOnMessage(anyLong());
    }

    @Test
    void normalMessageTouchesVisibleLastAndReachesPeer() {
        MessageService.SendResult r = service.send(ME, CONV, "selam", "c1");

        assertFalse(r.message().removed());
        verify(convs).touchLastVisible(CONV, 100L);
        verify(convs, never()).markShadowed(anyLong());
        verify(bus).publish(org.mockito.ArgumentMatchers.eq("messages"),
                org.mockito.ArgumentMatchers.argThat((java.util.Collection<Long> c) -> c.contains(PEER)), any());
    }

    @Test
    void suppressedMessageIsFilteredFromPeerHistoryQueriesAndStaysSentForSender() {
        direct.setShadowed(true);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, PEER))
                .thenReturn(Optional.of(ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER)));
        when(messages.beforeCleared(anyLong(), any(), anyLong(), anyLong(), any(), any())).thenReturn(List.of());

        service.history(PEER, CONV, null, null, 30);

        // gorunurluk suzgeci goruntuleyen kimligiyle sorgulanir (gonderen kendi bastirilmislarini gorur)
        verify(messages).beforeCleared(org.mockito.ArgumentMatchers.eq(CONV), any(), org.mockito.ArgumentMatchers.eq(0L),
                org.mockito.ArgumentMatchers.eq(PEER), any(), any());
    }

    @Test
    void replyToSuppressedMessageOfOtherUserIsNotFound() {
        Message parent = new Message();
        parent.setId(5L);
        parent.setConversationId(CONV);
        parent.setSenderId(PEER);
        parent.setSuppressed(true);
        when(messages.findById(5L)).thenReturn(Optional.of(parent));

        assertEquals("MESSAGE_NOT_FOUND", assertThrows(ApiException.class,
                () -> service.send(ME, CONV, "selam", "c9", 5L)).code());
    }

    @Test
    void rateLimitIsEnforcedPerUserPerMinute() {
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "x"))
                .when(limiter).check("msg:user:" + ME, 30, Duration.ofMinutes(1));

        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, "selam", "c1"));

        assertEquals("RATE_LIMITED", e.code());
        verify(messages, never()).saveAndFlush(any());
    }

    @Test
    void duplicateClientIdReturnsExistingMessageWithoutRateLimitOrDelivery() {
        Message existing = new Message();
        existing.setId(77L);
        existing.setConversationId(CONV);
        existing.setSenderId(ME);
        existing.setClientId("c1");
        existing.setBody("selam");
        when(messages.findByConversationIdAndSenderIdAndClientId(CONV, ME, "c1")).thenReturn(Optional.of(existing));

        MessageService.SendResult r = service.send(ME, CONV, "selam", "c1");

        assertFalse(r.created());
        assertEquals(77L, r.message().id());
        // tekrarli clientId yolu da kaba siniri harcar (eskiden hic sinirlanmiyordu); mesaj basina sinir uygulanmaz
        verify(limiter).check(startsWith("msg:all:"), anyInt(), any());
        verify(limiter, never()).check(startsWith("msg:user:"), anyInt(), any());
        verifyNoInteractions(bus);
        verify(messages, never()).saveAndFlush(any());
    }

    @Test
    void concurrentDuplicateInsertFallsBackToWinner() {
        Message winner = new Message();
        winner.setId(88L);
        winner.setConversationId(CONV);
        winner.setSenderId(ME);
        winner.setClientId("c1");
        winner.setBody("selam");
        when(messages.findByConversationIdAndSenderIdAndClientId(CONV, ME, "c1"))
                .thenReturn(Optional.empty(), Optional.of(winner));
        when(messages.saveAndFlush(any(Message.class))).thenThrow(new DataIntegrityViolationException("uq_message_client"));

        MessageService.SendResult r = service.send(ME, CONV, "selam", "c1");

        assertFalse(r.created());
        assertEquals(88L, r.message().id());
        verifyNoInteractions(bus);
    }

    @Test
    void emptyAndWhitespaceOnlyMessagesAreRejected() {
        for (String text : new String[] {"", "   ", "\n\t ", "​‮", null}) {
            ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, text, "c1"));
            assertEquals("EMPTY_MESSAGE", e.code());
        }
    }

    @Test
    void messageOver2000CharsIsRejected() {
        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, "a".repeat(2001), "c1"));
        assertEquals("MESSAGE_TOO_LONG", e.code());

        assertTrue(service.send(ME, CONV, "a".repeat(2000), "c2").created());
    }

    @Test
    void sendPersistsPublishesAndNotifiesOnlyOfflineRecipients() {
        when(presence.onlineAmong(any())).thenReturn(Set.of());

        MessageService.SendResult r = service.send(ME, CONV, "  <b>selam</b> & hos  ", "c1");

        assertTrue(r.created());
        assertEquals("<b>selam</b> & hos", r.message().text()); // duz metin: etiket silinmez, kirpilir
        verify(convs).touchLastMessage(eq(CONV), eq(100L), any());
        verify(members).advanceRead(CONV, ME, 100L);
        ArgumentCaptor<List<Long>> to = ArgumentCaptor.forClass(List.class);
        verify(bus).publish(eq("messages"), to.capture(), any(MessageView.class));
        assertEquals(List.of(ME, PEER), to.getValue());
        verify(notifications).sendNewMessage(eq(PEER), eq("Ali"), isNull(), any(), eq(true)); // onizleme kapali: metin yok
    }

    @Test
    void sendSealsBodyBeforePersistAndNeverPassesPlaintextToNotificationWhenPreviewOff() {
        when(presence.onlineAmong(any())).thenReturn(Set.of());

        service.send(ME, CONV, "cok gizli metin", "c1");

        ArgumentCaptor<Message> draft = ArgumentCaptor.forClass(Message.class);
        verify(codec).seal(draft.capture(), eq("cok gizli metin"));
        assertEquals(CONV, draft.getValue().getConversationId());
        assertEquals(ME, draft.getValue().getSenderId());
        assertEquals("c1", draft.getValue().getClientId());
        verify(notifications).sendNewMessage(eq(PEER), anyString(), isNull(), any(), eq(true));
    }

    @Test
    void previewEnabledSendsTruncatedPreviewOnlyAsPushBody() {
        MessageService withPreview = new MessageService(convs, members, messages, users, blocks, limiter, bus,
                presence, notifications, reports, mock(PlatformTransactionManager.class), codec, assembler, true);
        when(presence.onlineAmong(any())).thenReturn(Set.of());

        withPreview.send(ME, CONV, "a".repeat(150), "c9");

        ArgumentCaptor<String> prev = ArgumentCaptor.forClass(String.class);
        verify(notifications).sendNewMessage(eq(PEER), anyString(), prev.capture(), any(), eq(true));
        assertEquals(101, prev.getValue().length()); // 100 karakter + "..."
    }

    @Test
    void sealFailureSurfacesAsUnavailableAndNothingIsPersisted() {
        org.mockito.Mockito.doThrow(new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "CRYPTO_UNAVAILABLE", "x"))
                .when(codec).seal(any(Message.class), anyString());

        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, "selam", "c1"));

        assertEquals("CRYPTO_UNAVAILABLE", e.code());
        verify(messages, never()).saveAndFlush(any());
        verifyNoInteractions(bus);
    }

    @Test
    void onlineRecipientGetsNoPushNotification() {
        when(presence.onlineAmong(any())).thenReturn(Set.of(PEER));

        service.send(ME, CONV, "selam", "c1");

        verifyNoInteractions(notifications);
    }

    @Test
    void readCursorAdvanceNotifiesOthersOnlyWhenItMoved() {
        when(members.advanceRead(CONV, ME, 40L)).thenReturn(1);
        when(members.advanceRead(CONV, ME, 10L)).thenReturn(0); // geri/ayni deger: imlec degismez

        service.markRead(ME, CONV, 40L);
        verify(bus).publish(eq("read-receipts"), anyCollection(), eq(new ReadReceipt(CONV, ME, 40L)));

        service.markRead(ME, CONV, 10L);
        verify(bus, org.mockito.Mockito.times(1)).publish(anyString(), anyCollection(), any());
    }

    @Test
    void markReadOnEmptyConversationIsNoOp() {
        direct.setLastMessageId(null);

        service.markRead(ME, CONV, 5L); // 400 degil: sessizce donmeli

        verify(members, never()).advanceRead(anyLong(), anyLong(), anyLong());
        verifyNoInteractions(bus);
    }

    @Test
    void markReadOverRateLimitIsSilentlyDropped() {
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "x"))
                .when(limiter).check(startsWith("read:"), anyInt(), any());

        service.markRead(ME, CONV, 40L);

        verify(members, never()).advanceRead(anyLong(), anyLong(), anyLong());
    }

    @Test
    void manyOfflineRecipientsAreNotifiedIndividuallyWithTheirOwnPrefs() {
        direct.setType(Conversation.Type.GROUP); // birebirde karsi taraf tek; toplu yol grup/oda icindir
        List<ConversationMember> room = new java.util.ArrayList<>();
        room.add(ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER));
        List<Long> others = new java.util.ArrayList<>();
        for (long id = 100; id < 100 + MessageService.BULK_NOTIFY_THRESHOLD + 5; id++) {
            room.add(ConversationMember.of(CONV, id, ConversationMember.Role.MEMBER));
            others.add(id);
        }
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(room);
        when(presence.onlineAmong(any())).thenReturn(Set.of());

        service.send(ME, CONV, "selam", "c1");

        verify(notifications, never()).sendBulk(any(), any(), anyString(), anyString(), any());
        for (Long id : others) {
            verify(notifications).sendNewMessage(eq(id), anyString(), any(), any(), eq(true)); // her aliciya kendi tercihiyle
        }
        verify(notifications, never()).sendNewMessage(eq(ME), anyString(), any(), any(), anyBoolean());
    }

    @Test
    void recipientViewingThisConversationGetsNoNotificationAtAll() {
        when(presence.onlineAmong(any())).thenReturn(Set.of());
        when(presence.viewingAmong(any(), eq(CONV))).thenReturn(Set.of(PEER));

        service.send(ME, CONV, "selam", "c1");

        verifyNoInteractions(notifications);
    }

    @Test
    void foregroundRecipientGetsInAppRowButNoPush() {
        when(presence.onlineAmong(any())).thenReturn(Set.of());
        when(presence.foregroundAmong(any())).thenReturn(Set.of(PEER));

        service.send(ME, CONV, "selam", "c1");

        verify(notifications).sendNewMessage(eq(PEER), anyString(), any(), any(), eq(false));
    }

    @Test
    void stickyArchivedRecipientGetsNoNotification() {
        ConversationMember archived = ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER);
        archived.setArchivedAt(java.time.Instant.now());
        archived.setArchiveSticky(true);
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(
                ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER), archived));
        when(presence.onlineAmong(any())).thenReturn(Set.of());

        service.send(ME, CONV, "selam", "c1");

        verifyNoInteractions(notifications);
    }

    @Test
    void suspendedRecipientGetsNoNotification() {
        User suspended = mock(User.class);
        when(suspended.getId()).thenReturn(PEER);
        when(suspended.isActive()).thenReturn(false);
        when(users.findAllById(any())).thenReturn(List.of(suspended));
        when(presence.onlineAmong(any())).thenReturn(Set.of());

        service.send(ME, CONV, "selam", "c1");

        verifyNoInteractions(notifications);
    }

    @Test
    void notificationDataCarriesConversationType() {
        when(presence.onlineAmong(any())).thenReturn(Set.of());

        service.send(ME, CONV, "selam", "c1");

        ArgumentCaptor<Map<String, String>> d = ArgumentCaptor.forClass(Map.class);
        verify(notifications).sendNewMessage(eq(PEER), anyString(), any(), d.capture(), eq(true));
        assertEquals("DIRECT", d.getValue().get("conversationType"));
    }

    @Test
    void readCursorCannotPassLastMessage() {
        ApiException e = assertThrows(ApiException.class, () -> service.markRead(ME, CONV, 51L));
        assertEquals("INVALID_MESSAGE_ID", e.code());
        verify(members, never()).advanceRead(anyLong(), anyLong(), anyLong());
    }

    @Test
    void historyRequiresParticipantAndRejectsBeforePlusAfter() {
        assertEquals(HttpStatus.NOT_FOUND,
                assertThrows(ApiException.class, () -> service.history(99L, CONV, null, null, 30)).status());
        assertEquals("VALIDATION_ERROR",
                assertThrows(ApiException.class, () -> service.history(ME, CONV, 5L, 3L, 30)).code());
    }

    @Test
    void reportRequiresMembershipOfTheMessageConversation() {
        Message m = new Message();
        m.setId(5L);
        m.setConversationId(CONV);
        when(messages.findById(5L)).thenReturn(Optional.of(m));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, 99L)).thenReturn(Optional.empty());

        ApiException e = assertThrows(ApiException.class,
                () -> service.report(99L, 5L, new edu.bingol.backend.messaging.dto.MessagingDtos.ReportMessageRequest(
                        edu.bingol.backend.moderation.ReportReason.SPAM, null)));

        assertEquals("MESSAGE_NOT_FOUND", e.code());
        verifyNoInteractions(reports);
    }

    // --- T2 regresyon testleri ---

    @Test
    void lengthLimitCountsCodePointsNotUtf16Units() {
        String emoji = new String(Character.toChars(0x1F600));
        assertTrue(service.send(ME, CONV, emoji.repeat(2000), "e1").created()); // 4000 UTF-16 birimi, 2000 karakter
        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, emoji.repeat(2001), "e2"));
        assertEquals("MESSAGE_TOO_LONG", e.code());
    }

    @Test
    void deletedOrSuspendedSenderWithStaleTokenCannotSend() {
        User gone = new User();
        gone.setId(ME);
        gone.setStatus(edu.bingol.backend.user.UserStatus.DELETED);
        when(users.findById(ME)).thenReturn(Optional.of(gone));

        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, "hayalet", "c1"));

        assertEquals(HttpStatus.FORBIDDEN, e.status());
        verify(messages, never()).saveAndFlush(any());
        verifyNoInteractions(bus);
    }

    @Test
    void nonParticipantGetsNotFoundEvenIfAccountInactive() {
        // Uyelik kontrolu once gelir: yabanci icin yanit hesap durumuna gore degismez (varlik sizmaz).
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, 99L)).thenReturn(Optional.empty());
        assertEquals(HttpStatus.NOT_FOUND, assertThrows(ApiException.class, () -> service.send(99L, CONV, "x", "c1")).status());
    }

    @Test
    void typingFromNonParticipantIsRejectedAndNothingPublished() {
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, 99L)).thenReturn(Optional.empty());
        assertThrows(ApiException.class, () -> service.typing(99L, CONV));
        verifyNoInteractions(bus);
    }

    @Test
    void groupHistoryMasksBlockedSendersMessages() {
        Conversation g = new Conversation();
        g.setId(11L);
        g.setType(Conversation.Type.GROUP);
        when(convs.findById(11L)).thenReturn(Optional.of(g));
        ConversationMember me = ConversationMember.of(11L, ME, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(11L, ME)).thenReturn(Optional.of(me));
        when(blocks.hiddenFrom(ME)).thenReturn(Set.of(PEER));
        Message m = new Message();
        m.setId(5L);
        m.setConversationId(11L);
        m.setSenderId(PEER);
        m.setBody("gizli");
        when(messages.before(eq(11L), any(), any(), any())).thenReturn(List.of(m));

        var page = service.history(ME, 11L, null, null, 30);

        assertTrue(page.items().get(0).removed());
        assertFalse(page.items().get(0).text().contains("gizli"));
    }

    // --- T13: yanit, sessize alma, arsiv ---

    private Message parent(Long id, Long conv, String body) {
        Message p = new Message();
        p.setId(id);
        p.setConversationId(conv);
        p.setSenderId(PEER);
        p.setClientId("p" + id);
        p.setBody(body);
        p.setCreatedAt(java.time.Instant.now().minusSeconds(30));
        when(messages.findById(id)).thenReturn(Optional.of(p));
        when(messages.findAllById(any())).thenAnswer(inv -> {
            java.util.Collection<Long> ids = inv.getArgument(0);
            return ids.contains(id) ? List.of(p) : List.of();
        });
        return p;
    }

    @Test
    void replyStoresParentIdAndReturnsResolvedPreview() {
        parent(60L, CONV, "x".repeat(150));

        MessageService.SendResult r = service.send(ME, CONV, "cevap", "c1", 60L);

        ArgumentCaptor<Message> draft = ArgumentCaptor.forClass(Message.class);
        verify(messages).saveAndFlush(draft.capture());
        assertEquals(60L, draft.getValue().getReplyToMessageId());
        assertEquals(60L, r.message().replyTo().id());
        assertEquals(101, r.message().replyTo().text().length()); // 100 karakter + "…"
        assertFalse(r.message().replyTo().deleted());
    }

    @Test
    void replyToOtherConversationIs404() {
        parent(61L, 999L, "baska konusma");

        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, "cevap", "c1", 61L));

        assertEquals("MESSAGE_NOT_FOUND", e.code());
        verify(messages, never()).saveAndFlush(any());
    }

    @Test
    void replyToDeletedOrMissingMessageIs404() {
        Message p = parent(62L, CONV, "x");
        p.setDeletedAt(java.time.Instant.now());
        assertEquals("MESSAGE_NOT_FOUND",
                assertThrows(ApiException.class, () -> service.send(ME, CONV, "cevap", "c1", 62L)).code());
        assertEquals("MESSAGE_NOT_FOUND",
                assertThrows(ApiException.class, () -> service.send(ME, CONV, "cevap", "c2", 12345L)).code());
    }

    @Test
    void historyShowsDeletedParentAsSilindi() {
        Message p = parent(63L, CONV, "x");
        p.setDeletedAt(java.time.Instant.now());
        Message child = new Message();
        child.setId(64L);
        child.setConversationId(CONV);
        child.setSenderId(PEER);
        child.setClientId("k");
        child.setBody("yanit");
        child.setReplyToMessageId(63L);
        when(messages.before(eq(CONV), any(), isNull(), any())).thenReturn(List.of(child));

        MessageView v = service.history(ME, CONV, null, null, 30).items().get(0);

        assertTrue(v.replyTo().deleted());
        assertEquals(edu.bingol.backend.messaging.dto.MessagingDtos.DELETED_TEXT, v.replyTo().text());
    }

    @Test
    void deletedMessageInHistoryShowsTombstoneWithoutContent() {
        Message gone = new Message();
        gone.setId(70L);
        gone.setConversationId(CONV);
        gone.setSenderId(PEER);
        gone.setClientId("g");
        gone.setDeletedAt(java.time.Instant.now());
        gone.setReplyToMessageId(5L);
        when(messages.before(eq(CONV), any(), isNull(), any())).thenReturn(List.of(gone));

        MessageView v = service.history(ME, CONV, null, null, 30).items().get(0);

        assertTrue(v.deleted());
        assertTrue(v.removed());
        assertEquals(edu.bingol.backend.messaging.dto.MessagingDtos.DELETED_TEXT, v.text());
        assertEquals(null, v.replyTo());
    }

    @Test
    void mutedRecipientGetsWebSocketButNoPushOrInAppNotification() {
        ConversationMember mutedPeer = ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER);
        mutedPeer.setMutedUntil(java.time.Instant.now().plusSeconds(3600));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(
                ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER), mutedPeer));
        when(presence.onlineAmong(any())).thenReturn(Set.of());

        service.send(ME, CONV, "selam", "c1");

        ArgumentCaptor<List<Long>> to = ArgumentCaptor.forClass(List.class);
        verify(bus).publish(eq("messages"), to.capture(), any(MessageView.class));
        assertTrue(to.getValue().contains(PEER));
        verifyNoInteractions(notifications);
    }

    @Test
    void expiredMuteStillNotifies() {
        ConversationMember expired = ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER);
        expired.setMutedUntil(java.time.Instant.now().minusSeconds(5));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(
                ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER), expired));
        when(presence.onlineAmong(any())).thenReturn(Set.of());

        service.send(ME, CONV, "selam", "c1");

        verify(notifications).sendNewMessage(eq(PEER), anyString(), any(), any(), eq(true));
    }

    @Test
    void newMessageUnarchivesNonStickyArchives() {
        service.send(ME, CONV, "selam", "c1");

        verify(members).unarchiveOnMessage(CONV);
    }
}

