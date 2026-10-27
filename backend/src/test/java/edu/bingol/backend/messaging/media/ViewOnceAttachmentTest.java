package edu.bingol.backend.messaging.media;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.config.StorageProperties;
import edu.bingol.backend.crypto.CryptoService;
import edu.bingol.backend.crypto.CryptoTestSupport;
import edu.bingol.backend.crypto.KeyProvider;
import edu.bingol.backend.crypto.MediaBlobCipherAdapter;
import edu.bingol.backend.media.BlobCipher;
import edu.bingol.backend.media.ImageProcessor;
import edu.bingol.backend.media.MediaUrlSigner;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.messaging.Conversation;
import edu.bingol.backend.messaging.ConversationMember;
import edu.bingol.backend.messaging.ConversationMemberRepository;
import edu.bingol.backend.messaging.ConversationRepository;
import edu.bingol.backend.messaging.Message;
import edu.bingol.backend.messaging.MessageRepository;
import edu.bingol.backend.messaging.dto.MessagingDtos.ViewedEvent;
import edu.bingol.backend.messaging.ws.ChatEventBus;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ContentBlocklist;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;

/** Tek gosterimlik gorsel: acis kurallari, gorunum alanlari, olay, bayt silme. */
class ViewOnceAttachmentTest {

    private static final Long ME = 1L;
    private static final Long PEER = 2L;
    private static final Long THIRD = 3L;
    private static final Long CONV = 10L;

    @TempDir
    Path dir;

    final Map<Long, MessageAttachment> db = new HashMap<>();
    final Set<String> viewed = new HashSet<>();
    final AtomicLong seq = new AtomicLong(100);
    final MessageAttachmentRepository repo = mock(MessageAttachmentRepository.class);
    final MessageAttachmentViewRepository viewsRepo = mock(MessageAttachmentViewRepository.class);
    final ConversationRepository convs = mock(ConversationRepository.class);
    final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    final MessageRepository messages = mock(MessageRepository.class);
    final UserRepository users = mock(UserRepository.class);
    final BlockService blocks = mock(BlockService.class);
    final ChatEventBus bus = mock(ChatEventBus.class);
    final Map<Long, Message> messageDb = new HashMap<>();

    PrivateMediaStore store;
    MessageAttachmentService service;
    Conversation conv;
    List<ConversationMember> active;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        MediaProperties props = new MediaProperties(0, 4, 0, 0, 0, null, null, null, null, true, null, null, null, null);
        KeyProvider kp = CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(7), "");
        ObjectProvider<BlobCipher> cipher = mock(ObjectProvider.class);
        when(cipher.getIfAvailable(any())).thenReturn(new MediaBlobCipherAdapter(kp, new CryptoService()));
        store = new PrivateMediaStore(new StorageProperties(dir.toString()), props, new ImageProcessor(props), cipher);
        service = new MessageAttachmentService(repo, convs, members, messages, users, blocks, mock(RateLimiter.class),
                store, new MediaUrlSigner(props, "test-secret-test-secret-test-secret-1234"), props,
                mock(ContentBlocklist.class), 10, 200, 4, 20, 300);
        service.setViewsRepo(viewsRepo);
        service.setBus(bus);

        when(repo.save(any(MessageAttachment.class))).thenAnswer(inv -> {
            MessageAttachment a = inv.getArgument(0);
            if (a.getId() == null) {
                a.setId(seq.incrementAndGet());
            }
            db.put(a.getId(), a);
            return a;
        });
        when(repo.findById(anyLong())).thenAnswer(inv -> Optional.ofNullable(db.get(inv.<Long>getArgument(0))));
        when(repo.findByMessageIdIn(anyCollection())).thenAnswer(inv -> db.values().stream()
                .filter(a -> a.getMessageId() != null && ((java.util.Collection<Long>) inv.getArgument(0))
                        .contains(a.getMessageId())).toList());
        when(viewsRepo.existsByAttachmentIdAndUserId(anyLong(), anyLong())).thenAnswer(
                inv -> viewed.contains(inv.getArgument(0) + ":" + inv.getArgument(1)));
        when(viewsRepo.saveAndFlush(any(MessageAttachmentView.class))).thenAnswer(inv -> {
            MessageAttachmentView v = inv.getArgument(0);
            if (!viewed.add(v.getAttachmentId() + ":" + v.getUserId())) {
                throw new DataIntegrityViolationException("dup");
            }
            return v;
        });
        when(viewsRepo.countByAttachmentId(anyLong())).thenAnswer(inv -> viewed.stream()
                .filter(k -> k.startsWith(inv.getArgument(0) + ":")).count());
        when(viewsRepo.viewedBy(anyLong(), anyCollection())).thenAnswer(inv -> {
            List<Long> out = new ArrayList<>();
            for (Long id : (java.util.Collection<Long>) inv.getArgument(1)) {
                if (viewed.contains(id + ":" + inv.getArgument(0))) {
                    out.add(id);
                }
            }
            return out;
        });
        when(viewsRepo.viewedByAnyone(anyCollection())).thenAnswer(inv -> {
            List<Long> out = new ArrayList<>();
            for (Long id : (java.util.Collection<Long>) inv.getArgument(0)) {
                if (viewed.stream().anyMatch(k -> k.startsWith(id + ":"))) {
                    out.add(id);
                }
            }
            return out;
        });

        conv = new Conversation();
        conv.setId(CONV);
        conv.setType(Conversation.Type.DIRECT);
        when(convs.findById(CONV)).thenReturn(Optional.of(conv));
        active = new ArrayList<>(List.of(ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER),
                ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER)));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenAnswer(inv -> active);
        for (Long id : List.of(ME, PEER, THIRD)) {
            when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, id))
                    .thenReturn(Optional.of(ConversationMember.of(CONV, id, ConversationMember.Role.MEMBER)));
            User u = new User();
            u.setId(id);
            when(users.findById(id)).thenReturn(Optional.of(u));
        }
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(messages.findById(anyLong())).thenAnswer(inv -> Optional.ofNullable(messageDb.get(inv.<Long>getArgument(0))));
    }

    /** ME'nin gonderdigi tek gosterimlik ek (diskte gercek sifreli bayt). */
    MessageAttachment viewOnce() throws Exception {
        var pm = store.store(MessageAttachmentService.BUCKET,
                MessageAttachmentServiceTest.png(300, 200), edu.bingol.backend.media.ImageKind.CHAT);
        MessageAttachment a = new MessageAttachment();
        a.setConversationId(CONV);
        a.setUploaderId(ME);
        a.setStorageKey(pm.key());
        a.setThumbKey(pm.thumbKey());
        a.setWidth(pm.width());
        a.setHeight(pm.height());
        a.setBytes(pm.bytes());
        a.setContentType(pm.contentType());
        a.setViewOnce(true);
        repo.save(a);
        Message m = new Message();
        m.setId(900L + a.getId());
        m.setConversationId(CONV);
        m.setSenderId(ME);
        m.setCreatedAt(Instant.now());
        messageDb.put(m.getId(), m);
        a.setMessageId(m.getId());
        return a;
    }

    static ApiException fail(org.junit.jupiter.api.function.Executable e) {
        return assertThrows(ApiException.class, e);
    }

    @Test
    void recipientOpensOnceThenGets410AndBytesAreDeletedInDirect() throws Exception {
        MessageAttachment a = viewOnce();

        var resp = service.stream(PEER, CONV, a.getId(), false);

        assertEquals(HttpStatus.OK, resp.getStatusCode());
        String cc = resp.getHeaders().getCacheControl();
        assertTrue(cc.contains("no-store") && cc.contains("private"), cc);
        assertEquals("inline", resp.getHeaders().getFirst("Content-Disposition"));
        ApiException second = fail(() -> service.stream(PEER, CONV, a.getId(), false));
        assertEquals(HttpStatus.GONE, second.status());
        assertEquals("MEDIA_VIEW_ONCE_EXPIRED", second.code());
        assertNotNull(a.getPurgedAt());
        assertNull(store.read(MessageAttachmentService.BUCKET, a.getStorageKey()));
    }

    @Test
    void openPublishesViewedEventToSender() throws Exception {
        MessageAttachment a = viewOnce();

        service.stream(PEER, CONV, a.getId(), false);

        ArgumentCaptor<Object> ev = ArgumentCaptor.forClass(Object.class);
        verify(bus).publish(eq("message-events"), eq(List.of(ME)), ev.capture());
        ViewedEvent e = (ViewedEvent) ev.getValue();
        assertEquals("viewed", e.type());
        assertEquals(CONV, e.conversationId());
        assertEquals(a.getMessageId(), e.messageId());
        assertEquals(a.getId(), e.attachmentId());
        assertEquals(PEER, e.userId());
        assertNotNull(e.at());
    }

    @Test
    void concurrentSecondOpenLosesTheInsertRaceWith410() throws Exception {
        conv.setType(Conversation.Type.GROUP);
        active.add(ConversationMember.of(CONV, THIRD, ConversationMember.Role.MEMBER)); // bayt silinmez
        MessageAttachment a = viewOnce();
        service.stream(PEER, CONV, a.getId(), false);
        // yarisan istek exists denetiminden gecti ama insert birincil anahtara takilir
        when(viewsRepo.existsByAttachmentIdAndUserId(anyLong(), anyLong())).thenReturn(false);

        ApiException e = fail(() -> service.stream(PEER, CONV, a.getId(), false));

        assertEquals("MEDIA_VIEW_ONCE_EXPIRED", e.code());
    }

    @Test
    void senderCannotOpenOwnViewOnce() throws Exception {
        MessageAttachment a = viewOnce();

        ApiException e = fail(() -> service.stream(ME, CONV, a.getId(), false));

        assertEquals(HttpStatus.FORBIDDEN, e.status());
        assertEquals("MEDIA_VIEW_ONCE_OWN", e.code());
        assertFalse(viewed.contains(a.getId() + ":" + ME));
    }

    @Test
    void thumbAndLinkAreNotFoundForViewOnce() throws Exception {
        MessageAttachment a = viewOnce();

        assertEquals(HttpStatus.NOT_FOUND, fail(() -> service.stream(PEER, CONV, a.getId(), true)).status());
        assertEquals(HttpStatus.NOT_FOUND, fail(() -> service.link(PEER, CONV, a.getId())).status());
        assertEquals(HttpStatus.NOT_FOUND, fail(() -> service.link(ME, CONV, a.getId())).status());
        assertTrue(viewed.isEmpty());
    }

    @Test
    void viewsAreViewerAwareAndNeverLeakThumb() throws Exception {
        MessageAttachment a = viewOnce();
        Long mid = a.getMessageId();

        AttachmentView sender = service.viewsFor(ME, List.of(mid)).get(mid).get(0);
        AttachmentView recipient = service.viewsFor(PEER, List.of(mid)).get(mid).get(0);
        assertTrue(sender.viewOnce() && recipient.viewOnce());
        assertNull(sender.url());
        assertNull(sender.thumbUrl());
        assertFalse(sender.viewed());
        assertEquals("/api/conversations/10/media/" + a.getId(), recipient.url());
        assertNull(recipient.thumbUrl());
        assertFalse(recipient.viewed());

        service.stream(PEER, CONV, a.getId(), false);

        AttachmentView sender2 = service.viewsFor(ME, List.of(mid)).get(mid).get(0);
        AttachmentView recipient2 = service.viewsFor(PEER, List.of(mid)).get(mid).get(0);
        assertTrue(sender2.viewed());
        assertNull(sender2.url());
        assertTrue(recipient2.viewed());
        assertNull(recipient2.url());
    }

    @Test
    void groupKeepsBytesUntilAllRecipientsViewOrTtlPasses() throws Exception {
        conv.setType(Conversation.Type.GROUP);
        active.add(ConversationMember.of(CONV, THIRD, ConversationMember.Role.MEMBER));
        MessageAttachment a = viewOnce();

        service.stream(PEER, CONV, a.getId(), false);
        assertNull(a.getPurgedAt()); // THIRD henuz acmadi
        AttachmentView seen = service.viewsFor(ME, List.of(a.getMessageId())).get(a.getMessageId()).get(0);
        assertTrue(seen.viewed()); // gonderen: en az bir alici acti
        assertFalse(service.viewsFor(THIRD, List.of(a.getMessageId())).get(a.getMessageId()).get(0).viewed());

        // sure dolunca zamanli temizlik kalan baytlari siler; goruntuleme bilgisi kalir
        a.setCreatedAt(Instant.now().minus(Duration.ofHours(25)));
        when(repo.expiredViewOnce(any(), any())).thenReturn(List.of(a));
        assertEquals(1, service.purgeExpiredViewOnce());
        assertNotNull(a.getPurgedAt());
        assertNull(store.read(MessageAttachmentService.BUCKET, a.getStorageKey()));
        ApiException late = fail(() -> service.stream(THIRD, CONV, a.getId(), false));
        assertEquals("MEDIA_VIEW_ONCE_EXPIRED", late.code());
        assertNull(service.viewsFor(THIRD, List.of(a.getMessageId())).get(a.getMessageId()).get(0).url());
        assertTrue(service.viewsFor(PEER, List.of(a.getMessageId())).get(a.getMessageId()).get(0).viewed());
    }

    @Test
    void nonMemberGets404() throws Exception {
        MessageAttachment a = viewOnce();
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, 99L)).thenReturn(Optional.empty());

        assertEquals(HttpStatus.NOT_FOUND, fail(() -> service.stream(99L, CONV, a.getId(), false)).status());
        verify(viewsRepo, org.mockito.Mockito.never()).saveAndFlush(any(MessageAttachmentView.class));
    }

    @Test
    void claimMarksAttachmentsViewOnce() {
        when(repo.claim(anyLong(), anyCollection(), anyLong(), anyLong())).thenReturn(1);
        service.claim(5L, ME, CONV, List.of(7L), true);

        verify(repo).claim(eq(5L), eq(List.of(7L)), eq(ME), eq(CONV));
        verify(repo).markViewOnce(List.of(7L));
    }
}
