package edu.bingol.backend.messaging;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.messaging.dto.MessagingDtos.MessageView;
import edu.bingol.backend.messaging.dto.MessagingDtos.ShareRequest;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.messaging.ws.PresenceService;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ReportService;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.share.ShareCard;
import edu.bingol.backend.share.ShareRef;
import edu.bingol.backend.share.ShareService;
import edu.bingol.backend.share.ShareType;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.transaction.PlatformTransactionManager;

/** Mesajla icerik paylasimi: dogrulama, kayit, alici basina kart, kullanilamaz kart, push onizlemesi (3 dil). */
class MessageServiceShareTest {

    private static final Long ME = 1L;
    private static final Long PEER = 2L;
    private static final Long CONV = 10L;
    private static final ShareRef POST5 = new ShareRef(ShareType.POST, 5);

    private final ConversationRepository convs = mock(ConversationRepository.class);
    private final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    private final MessageRepository messages = mock(MessageRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final RateLimiter limiter = mock(RateLimiter.class);
    private final ChatEventBus bus = mock(ChatEventBus.class);
    private final PresenceService presence = mock(PresenceService.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final MessageCodec codec = mock(MessageCodec.class);
    private final MessageReactionRepository reactions = mock(MessageReactionRepository.class);
    private final ShareService shares = mock(ShareService.class);
    private final MessageViewAssembler assembler = new MessageViewAssembler(messages, reactions, codec);
    private final MessageService service = new MessageService(convs, members, messages, users, blocks, limiter, bus,
            presence, notifications, mock(ReportService.class), mock(PlatformTransactionManager.class), codec, assembler);

    private static ShareCard card(boolean available) {
        return new ShareCard("POST", 5L, available, available ? "Kampus bahar" : null, available ? "Ayse" : null,
                available ? "/api/posts/media/55?thumb=true" : null, available ? "PHOTO" : null,
                "https://bukampus.com.tr/s/p/5");
    }

    @BeforeEach
    void setUp() {
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
        peer.setLanguage("en");
        User me = new User();
        me.setId(ME);
        me.setDisplayName("Ali");
        when(users.findById(PEER)).thenReturn(Optional.of(peer));
        when(users.findById(ME)).thenReturn(Optional.of(me));
        when(users.findAllById(anyCollection())).thenReturn(List.of(peer));
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
        when(presence.onlineAmong(any())).thenReturn(Set.of());
        when(presence.viewingAmong(any(), anyLong())).thenReturn(Set.of());
        service.setShares(shares);
        assembler.setShares(shares);
        when(shares.requireVisible(ME, "POST", 5L)).thenReturn(POST5);
        when(shares.requireVisible(ME, "post", 5L)).thenReturn(POST5);
        when(shares.cards(anyLong(), anyCollection())).thenAnswer(inv -> Map.of(POST5, card(true)));
        when(shares.cardsForViewers(eq(POST5), anyCollection())).thenAnswer(inv -> {
            java.util.Map<Long, ShareCard> out = new java.util.HashMap<>();
            for (Long id : (java.util.Collection<Long>) inv.getArgument(1)) {
                out.put(id, id.equals(PEER) ? card(false) : card(true)); // alici goremiyor
            }
            return out;
        });
        ResourceBundleMessageSource ms = new ResourceBundleMessageSource();
        ms.setBasename("i18n/share");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false);
        service.setI18n(new I18n(ms, users));
    }

    @Test
    void shareOnlyMessageIsSavedWithReferenceAndAllowsEmptyNote() {
        MessageService.SendResult r = service.send(ME, CONV, "", "c1", null, null, null,
                new ShareRequest("POST", 5L));

        ArgumentCaptor<Message> saved = ArgumentCaptor.forClass(Message.class);
        verify(messages).saveAndFlush(saved.capture());
        assertEquals("POST", saved.getValue().getShareType());
        assertEquals(5L, saved.getValue().getShareRefId());
        assertTrue(r.created());
        assertNotNull(r.message().share());
        assertTrue(r.message().share().available());
        assertEquals("Kampus bahar", r.message().share().title());
        assertEquals("https://bukampus.com.tr/s/p/5", r.message().share().url());
    }

    @Test
    void shareWithShortNoteKeepsTheNote() {
        MessageService.SendResult r = service.send(ME, CONV, "Buna bak!", "c1", null, null, null,
                new ShareRequest("post", 5L));

        assertEquals("Buna bak!", r.message().text());
        assertEquals("POST", r.message().share().type());
    }

    @Test
    void invisibleOrUnknownTargetIsRejectedBeforeAnyWrite() {
        ApiException bad = new ApiException(org.springframework.http.HttpStatus.UNPROCESSABLE_ENTITY,
                "SHARE_TARGET_INVALID", "x");
        when(shares.requireVisible(ME, "POST", 99L)).thenThrow(bad);

        ApiException e = assertThrows(ApiException.class,
                () -> service.send(ME, CONV, "", "c1", null, null, null, new ShareRequest("POST", 99L)));

        assertEquals("SHARE_TARGET_INVALID", e.code());
        verify(messages, never()).saveAndFlush(any());
        verify(limiter, never()).check(org.mockito.ArgumentMatchers.startsWith("msg:user:"), anyInt(), any());
    }

    @Test
    void shareCannotBeCombinedWithAttachmentsOrViewOnce() {
        ApiException a = assertThrows(ApiException.class,
                () -> service.send(ME, CONV, "", "c1", null, List.of(3L), null, new ShareRequest("POST", 5L)));
        ApiException b = assertThrows(ApiException.class,
                () -> service.send(ME, CONV, "", "c2", null, null, true, new ShareRequest("POST", 5L)));

        assertEquals("SHARE_TARGET_INVALID", a.code());
        assertEquals("SHARE_TARGET_INVALID", b.code());
        verify(messages, never()).saveAndFlush(any());
    }

    @Test
    void emptyTextWithoutShareStillRejected() {
        ApiException e = assertThrows(ApiException.class, () -> service.send(ME, CONV, "  ", "c1"));

        assertEquals("EMPTY_MESSAGE", e.code());
    }

    @Test
    void recipientGetsUnavailableCardWithNoDetailWhileSenderSeesTheContent() {
        service.send(ME, CONV, "", "c1", null, null, null, new ShareRequest("POST", 5L));

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<Long>> to = ArgumentCaptor.forClass(List.class);
        ArgumentCaptor<MessageView> view = ArgumentCaptor.forClass(MessageView.class);
        verify(bus, times(2)).publish(eq("messages"), to.capture(), view.capture());
        for (int i = 0; i < 2; i++) {
            boolean toPeer = to.getAllValues().get(i).contains(PEER);
            ShareCard c = view.getAllValues().get(i).share();
            assertEquals(!toPeer, c.available());
            if (toPeer) {
                assertNull(c.title());
                assertNull(c.imageUrl());
                assertNull(c.subtitle());
            } else {
                assertEquals("Kampus bahar", c.title());
            }
        }
    }

    @Test
    void historyComputesCardsAtReadTimeForTheViewer() {
        Message m = new Message();
        m.setId(7L);
        m.setConversationId(CONV);
        m.setSenderId(ME);
        m.setClientId("x");
        m.setBody("");
        m.setShareType("POST");
        m.setShareRefId(5L);
        when(shares.cards(eq(PEER), anyCollection())).thenReturn(Map.of(POST5, card(false)));

        List<MessageView> forPeer = assembler.assemble(PEER, List.of(m), Set.of(), null);
        List<MessageView> forMe = assembler.assemble(ME, List.of(m), Set.of(), null);

        assertFalse(forPeer.get(0).share().available());
        assertNull(forPeer.get(0).share().title());
        assertTrue(forMe.get(0).share().available());
    }

    @Test
    void deletedMessageDoesNotExposeTheShareCard() {
        Message m = new Message();
        m.setId(7L);
        m.setConversationId(CONV);
        m.setSenderId(ME);
        m.setClientId("x");
        m.setBody("");
        m.setShareType("POST");
        m.setShareRefId(5L);
        m.setDeletedAt(java.time.Instant.now());

        MessageView v = assembler.assemble(PEER, List.of(m), Set.of(), null).get(0);

        assertNull(v.share());
        assertTrue(v.deleted());
    }

    @Test
    void conversationListPreviewIsNeutral() {
        MessageView full = MessageView.of(shareMsg()).withShare(card(true));

        MessageView neutral = full.withNeutralShare("🔗 Gönderi paylaştı");

        assertEquals("🔗 Gönderi paylaştı", neutral.text());
        assertNull(neutral.share().title());
        assertNull(neutral.share().imageUrl());
        assertTrue(neutral.share().available());
        // not varsa metin korunur
        Message withNote = shareMsg();
        withNote.setBody("bak");
        assertEquals("bak", MessageView.of(withNote).withShare(card(true)).withNeutralShare("x").text());
    }

    private static Message shareMsg() {
        Message m = new Message();
        m.setId(8L);
        m.setConversationId(CONV);
        m.setSenderId(ME);
        m.setClientId("y");
        m.setBody("");
        m.setCreatedAt(java.time.Instant.parse("2026-11-05T10:00:00Z"));
        m.setShareType("POST");
        m.setShareRefId(5L);
        return m;
    }

    @Test
    void pushPreviewIsNeutralAndInTheRecipientsLanguage() {
        service.send(ME, CONV, "", "c1", null, null, null, new ShareRequest("POST", 5L));

        ArgumentCaptor<String> preview = ArgumentCaptor.forClass(String.class);
        verify(notifications).sendNewMessageBatch(any(), anyString(), preview.capture(), any(), anyInt());
        assertEquals("🔗 Shared a post", preview.getValue()); // alici dili "en"
    }

    @Test
    void pushPreviewAppendsTheSendersNote() {
        service.send(ME, CONV, "Bu cok guzel", "c1", null, null, null, new ShareRequest("POST", 5L));

        ArgumentCaptor<String> preview = ArgumentCaptor.forClass(String.class);
        verify(notifications).sendNewMessageBatch(any(), anyString(), preview.capture(), any(), anyInt());
        assertEquals("🔗 Shared a post: Bu cok guzel", preview.getValue());
    }

    @Test
    void sharePreviewLabelsExistInAllLanguages() {
        ResourceBundleMessageSource ms = new ResourceBundleMessageSource();
        ms.setBasename("i18n/share");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false);
        for (String lang : new String[] {"tr", "en", "ar"}) {
            for (ShareType t : ShareType.values()) {
                String key = "share.preview." + (t == ShareType.NEWS ? "NEWS" : t.name());
                String v = ms.getMessage(key, null, "MISSING", java.util.Locale.forLanguageTag(lang));
                assertFalse(v.equals("MISSING"), lang + " " + key);
                assertTrue(v.startsWith("🔗"), lang + " " + key);
            }
        }
    }
}
