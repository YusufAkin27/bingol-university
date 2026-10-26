package edu.bingol.backend.messaging.media;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
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
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ContentBlocklist;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Stream;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

/** T8: yukleme saldirilari, sifreli depo, erisim matrisi, gizleme/geri alma, imzali adres, temizlik. */
class MessageAttachmentServiceTest {

    private static final Long ME = 1L;
    private static final Long PEER = 2L;
    private static final Long OUTSIDER = 3L;
    private static final Long CONV = 10L;
    private static final Long OTHER_CONV = 11L;

    @TempDir
    Path dir;

    final Map<Long, MessageAttachment> db = new HashMap<>();
    final AtomicLong seq = new AtomicLong(100);
    final MessageAttachmentRepository repo = mock(MessageAttachmentRepository.class);
    final ConversationRepository convs = mock(ConversationRepository.class);
    final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    final MessageRepository messages = mock(MessageRepository.class);
    final UserRepository users = mock(UserRepository.class);
    final BlockService blocks = mock(BlockService.class);
    final RateLimiter limiter = mock(RateLimiter.class);
    final ContentBlocklist blocklist = mock(ContentBlocklist.class);
    final Map<Long, Message> messageDb = new HashMap<>();

    MediaProperties props;
    PrivateMediaStore store;
    MediaUrlSigner signer;
    MessageAttachmentService service;
    Conversation conv;
    ConversationMember meMember;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        props = new MediaProperties(0, 4, 0, 0, 0, null, null, null, null, true, null, null, null, null);
        KeyProvider kp = CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(7), "");
        ObjectProvider<BlobCipher> cipher = mock(ObjectProvider.class);
        when(cipher.getIfAvailable(any())).thenReturn(new MediaBlobCipherAdapter(kp, new CryptoService()));
        store = new PrivateMediaStore(new StorageProperties(dir.toString()), props, new ImageProcessor(props), cipher);
        signer = new MediaUrlSigner(props, "test-secret-test-secret-test-secret-1234");
        service = new MessageAttachmentService(repo, convs, members, messages, users, blocks, limiter, store, signer,
                props, blocklist, 10, 200, 4, 20, 300);

        when(repo.save(any(MessageAttachment.class))).thenAnswer(inv -> {
            MessageAttachment a = inv.getArgument(0);
            if (a.getId() == null) {
                a.setId(seq.incrementAndGet());
            }
            db.put(a.getId(), a);
            return a;
        });
        when(repo.findById(anyLong())).thenAnswer(inv -> Optional.ofNullable(db.get(inv.<Long>getArgument(0))));
        when(repo.findAllById(any())).thenAnswer(inv -> {
            List<MessageAttachment> out = new ArrayList<>();
            for (Long id : (Iterable<Long>) inv.getArgument(0)) {
                if (db.containsKey(id)) {
                    out.add(db.get(id));
                }
            }
            return out;
        });
        when(repo.existsByStorageKey(anyString())).thenAnswer(inv ->
                db.values().stream().anyMatch(a -> a.getStorageKey().equals(inv.getArgument(0))));

        conv = new Conversation();
        conv.setId(CONV);
        conv.setType(Conversation.Type.DIRECT);
        when(convs.findById(CONV)).thenReturn(Optional.of(conv));
        meMember = ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, ME)).thenReturn(Optional.of(meMember));
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, PEER))
                .thenReturn(Optional.of(ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER)));
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(
                ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER),
                ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER)));
        for (Long id : List.of(ME, PEER, OUTSIDER)) {
            User u = new User();
            u.setId(id);
            when(users.findById(id)).thenReturn(Optional.of(u));
        }
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(messages.findById(anyLong())).thenAnswer(inv -> Optional.ofNullable(messageDb.get(inv.<Long>getArgument(0))));
    }

    // ------------------------------------------------------------ yardimcilar

    static byte[] png(int w, int h) throws Exception {
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        for (int x = 0; x < w; x++) {
            for (int y = 0; y < h; y++) {
                img.setRGB(x, y, (x * 255 / w) << 16 | (y * 255 / h) << 8 | 90);
            }
        }
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(img, "png", out);
        return out.toByteArray();
    }

    static MultipartFile file(byte[] data, String name, String type) {
        return new MockMultipartFile("file", name, type, data);
    }

    AttachmentView uploadOk() throws Exception {
        return service.upload(ME, CONV, file(png(900, 600), "a.png", "image/png"));
    }

    long filesOnDisk() throws Exception {
        Path bucket = dir.resolve("_private").resolve("chat");
        if (!Files.isDirectory(bucket)) {
            return 0;
        }
        try (Stream<Path> s = Files.list(bucket)) {
            return s.count();
        }
    }

    /** Gonderilmis (mesaja bagli) ek olusturur. */
    MessageAttachment sent(Long uploader, Long messageSenderId, Instant messageAt) throws Exception {
        AttachmentView v = uploadOk();
        MessageAttachment a = db.get(v.id());
        a.setUploaderId(uploader);
        Message m = new Message();
        m.setId(500L + a.getId());
        m.setConversationId(CONV);
        m.setSenderId(messageSenderId);
        m.setCreatedAt(messageAt);
        messageDb.put(m.getId(), m);
        a.setMessageId(m.getId());
        return a;
    }

    // ------------------------------------------------------------ yukleme

    @Test
    void uploadStoresEncryptedCompressedImageAndReturnsAuthenticatedPaths() throws Exception {
        AttachmentView v = uploadOk();

        assertEquals("/api/conversations/10/media/" + v.id(), v.url());
        assertEquals(v.url() + "/thumb", v.thumbUrl());
        assertEquals("image/jpeg", v.contentType());
        assertTrue(v.bytes() <= props.limits(edu.bingol.backend.media.ImageKind.CHAT).maxStoredBytes());
        MessageAttachment a = db.get(v.id());
        assertEquals(ME, a.getUploaderId());
        assertNull(a.getMessageId());
        // diskteki baytlar sifreli: JPEG imzasi yok, sifreli cerceve imzasi var
        byte[] onDisk = Files.readAllBytes(dir.resolve("_private/chat").resolve(a.getStorageKey()));
        assertEquals("BUM1", new String(onDisk, 0, 4, java.nio.charset.StandardCharsets.US_ASCII));
        assertNotEquals((byte) 0xFF, onDisk[0]);
        // yetkili akis calisir ve cozulmus JPEG doner
        byte[] plain = store.read("chat", a.getStorageKey());
        assertEquals((byte) 0xFF, plain[0]);
        assertEquals((byte) 0xD8, plain[1]);
        var resp = service.stream(ME, CONV, a.getId(), false);
        assertEquals(HttpStatus.OK, resp.getStatusCode());
        String cc = resp.getHeaders().getCacheControl();
        assertTrue(cc.contains("no-store") && cc.contains("private"), cc);
        assertEquals("nosniff", resp.getHeaders().getFirst("X-Content-Type-Options"));
    }

    @Test
    void uploadRateLimitIsAppliedBeforeAnyProcessing() throws Exception {
        doThrow(new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "x"))
                .when(limiter).check(eq("chatmedia:min:" + ME), anyInt(), any());
        ApiException e = assertThrows(ApiException.class, this::uploadOk);
        assertEquals("RATE_LIMITED", e.code());
        assertEquals(0, filesOnDisk());
    }

    private static int anyInt() {
        return org.mockito.ArgumentMatchers.anyInt();
    }

    @Test
    void nonMemberCannotUpload() throws Exception {
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, OUTSIDER)).thenReturn(Optional.empty());
        ApiException e = assertThrows(ApiException.class,
                () -> service.upload(OUTSIDER, CONV, file(png(50, 50), "a.png", "image/png")));
        assertEquals(HttpStatus.NOT_FOUND, e.status());
        assertEquals(0, filesOnDisk());
    }

    @Test
    void suspendedUploaderIsRejected() throws Exception {
        User u = new User();
        u.setId(ME);
        u.setStatus(UserStatus.SUSPENDED);
        when(users.findById(ME)).thenReturn(Optional.of(u));
        ApiException e = assertThrows(ApiException.class, this::uploadOk);
        assertEquals("ACCOUNT_SUSPENDED", e.code());
    }

    @Test
    void blockedPeerCannotReceiveUploadInDirectConversation() throws Exception {
        when(blocks.isBlocked(ME, PEER)).thenReturn(true);
        ApiException e = assertThrows(ApiException.class, this::uploadOk);
        assertEquals("BLOCKED", e.code());
        assertEquals(0, filesOnDisk());
    }

    @Test
    void typeAndSizeAttacksAreRejectedAndLeaveNothingOnDisk() throws Exception {
        // bildirilen tur SVG/HTML
        assertEquals("INVALID_FILE", assertThrows(ApiException.class, () -> service.upload(ME, CONV,
                file("<svg/>".getBytes(), "a.svg", "image/svg+xml"))).code());
        assertEquals("INVALID_FILE", assertThrows(ApiException.class, () -> service.upload(ME, CONV,
                file("<html>".getBytes(), "a.html", "text/html"))).code());
        // uzanti png ama icerik GIF (sihirli bayt)
        byte[] gif = "GIF89a\u0001\u0000\u0001\u0000".getBytes(java.nio.charset.StandardCharsets.ISO_8859_1);
        assertEquals("INVALID_FILE", assertThrows(ApiException.class, () -> service.upload(ME, CONV,
                file(gif, "a.png", "image/png"))).code());
        // PNG gibi gorunen bozuk dosya
        byte[] fake = new byte[200];
        System.arraycopy(new byte[] {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A}, 0, fake, 0, 8);
        assertEquals("IMAGE_CORRUPT", assertThrows(ApiException.class, () -> service.upload(ME, CONV,
                file(fake, "a.png", "image/png"))).code());
        // ham yukleme siniri (5 MB)
        byte[] huge = new byte[(5 << 20) + 10];
        ApiException big = assertThrows(ApiException.class, () -> service.upload(ME, CONV,
                file(huge, "a.png", "image/png")));
        assertEquals(HttpStatus.PAYLOAD_TOO_LARGE, big.status());
        // bos dosya
        assertThrows(ApiException.class, () -> service.upload(ME, CONV, file(new byte[0], "a.png", "image/png")));
        assertEquals(0, filesOnDisk());
        assertTrue(db.isEmpty());
    }

    @Test
    void pendingUploadCapIsEnforced() throws Exception {
        when(repo.countByUploaderIdAndMessageIdIsNull(ME)).thenReturn(20L);
        ApiException e = assertThrows(ApiException.class, this::uploadOk);
        assertEquals("CHAT_MEDIA_PENDING_LIMIT", e.code());
        assertEquals(HttpStatus.TOO_MANY_REQUESTS, e.status());
    }

    @Test
    void blocklistedRawBytesAreRejectedWith422() throws Exception {
        byte[] raw = png(100, 100);
        when(blocklist.isBlocked(MessageAttachmentService.sha256Hex(raw))).thenReturn(true);
        ApiException e = assertThrows(ApiException.class, () -> service.upload(ME, CONV, file(raw, "a.png", "image/png")));
        assertEquals("MEDIA_BLOCKED", e.code());
        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, e.status());
        assertEquals(0, filesOnDisk());
    }

    @Test
    void blocklistedReencodedOutputIsRejectedAndNothingIsWritten() throws Exception {
        byte[] raw = png(100, 100);
        // Yonetici, yeniden kodlanmis (yonetici onizlemesinde gorulen) ciktinin ozetini eklemis olabilir
        byte[] processed = new ImageProcessor(props).process(raw, edu.bingol.backend.media.ImageKind.CHAT).data();
        when(blocklist.isBlocked(MessageAttachmentService.sha256Hex(processed))).thenReturn(true);
        ApiException e = assertThrows(ApiException.class, () -> service.upload(ME, CONV, file(raw, "a.png", "image/png")));
        assertEquals("MEDIA_BLOCKED", e.code());
        assertEquals(0, filesOnDisk());
        assertTrue(db.isEmpty());
    }

    // ------------------------------------------------------------ mesaja baglama

    @Test
    void precheckRejectsForeignUsedDuplicateCrossConversationAndTooMany() throws Exception {
        AttachmentView v = uploadOk();
        Long id = v.id();
        assertEquals(List.of(id), service.precheck(ME, CONV, List.of(id)));
        // baskasinin eki
        assertEquals("ATTACHMENT_INVALID", assertThrows(ApiException.class,
                () -> service.precheck(PEER, CONV, List.of(id))).code());
        // baska konusmada kullanma
        assertEquals("ATTACHMENT_INVALID", assertThrows(ApiException.class,
                () -> service.precheck(ME, OTHER_CONV, List.of(id))).code());
        // olmayan kimlik
        assertEquals("ATTACHMENT_INVALID", assertThrows(ApiException.class,
                () -> service.precheck(ME, CONV, List.of(99999L))).code());
        // ayni kimlik iki kez
        assertEquals("ATTACHMENT_INVALID", assertThrows(ApiException.class,
                () -> service.precheck(ME, CONV, List.of(id, id))).code());
        // en fazla 4
        assertEquals("ATTACHMENT_LIMIT", assertThrows(ApiException.class,
                () -> service.precheck(ME, CONV, List.of(1L, 2L, 3L, 4L, 5L))).code());
        // zaten bir mesaja bagli
        db.get(id).setMessageId(777L);
        assertEquals("ATTACHMENT_INVALID", assertThrows(ApiException.class,
                () -> service.precheck(ME, CONV, List.of(id))).code());
    }

    @Test
    void claimFailsWhenFewerRowsAreUpdatedThanRequested() {
        when(repo.claim(eq(5L), any(), eq(ME), eq(CONV))).thenReturn(1);
        ApiException e = assertThrows(ApiException.class, () -> service.claim(5L, ME, CONV, List.of(1L, 2L)));
        assertEquals("ATTACHMENT_INVALID", e.code());
        when(repo.claim(eq(6L), any(), eq(ME), eq(CONV))).thenReturn(2);
        service.claim(6L, ME, CONV, List.of(1L, 2L)); // tamam
    }

    // ------------------------------------------------------------ erisim matrisi

    @Test
    void accessMatrix() throws Exception {
        MessageAttachment a = sent(ME, ME, Instant.now());
        Long id = a.getId();
        // uyeler gorur
        assertTrue(service.accessible(ME, CONV, id).isPresent());
        assertTrue(service.accessible(PEER, CONV, id).isPresent());
        // uye olmayan
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, OUTSIDER)).thenReturn(Optional.empty());
        assertTrue(service.accessible(OUTSIDER, CONV, id).isEmpty());
        // IDOR: dogru kimlik, yanlis konusma
        assertTrue(service.accessible(ME, OTHER_CONV, id).isEmpty());
        assertThrows(ApiException.class, () -> service.stream(OUTSIDER, CONV, id, false));
        // engel: PEER, gonderen ME'yi engellemis
        when(blocks.hiddenFrom(PEER)).thenReturn(Set.of(ME));
        assertTrue(service.accessible(PEER, CONV, id).isEmpty());
        when(blocks.hiddenFrom(PEER)).thenReturn(Set.of());
        // askidaki yukleyen baskalarina kapanir, kendisi icin degil (zaten token reddedilir)
        User susp = new User();
        susp.setId(ME);
        susp.setStatus(UserStatus.SUSPENDED);
        when(users.findById(ME)).thenReturn(Optional.of(susp));
        assertTrue(service.accessible(PEER, CONV, id).isEmpty());
        User ok = new User();
        ok.setId(ME);
        when(users.findById(ME)).thenReturn(Optional.of(ok));
        assertTrue(service.accessible(PEER, CONV, id).isPresent());
        // mesaj moderasyonla gizlendi
        messageDb.get(a.getMessageId()).setHiddenAt(Instant.now());
        assertTrue(service.accessible(PEER, CONV, id).isEmpty());
        assertTrue(service.accessible(ME, CONV, id).isEmpty());
    }

    @Test
    void groupMemberCannotSeeImagesSentBeforeJoining() throws Exception {
        conv.setType(Conversation.Type.GROUP);
        meMember.setJoinedAt(Instant.now());
        MessageAttachment before = sent(PEER, PEER, Instant.now().minus(Duration.ofHours(2)));
        MessageAttachment after = sent(PEER, PEER, Instant.now().plus(Duration.ofSeconds(5)));
        assertTrue(service.accessible(ME, CONV, before.getId()).isEmpty());
        assertTrue(service.accessible(ME, CONV, after.getId()).isPresent());
    }

    @Test
    void leftMemberLosesAccess() throws Exception {
        MessageAttachment a = sent(PEER, PEER, Instant.now());
        assertTrue(service.accessible(ME, CONV, a.getId()).isPresent());
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, ME)).thenReturn(Optional.empty());
        assertTrue(service.accessible(ME, CONV, a.getId()).isEmpty());
    }

    @Test
    void unsentUploadIsVisibleOnlyToItsUploader() throws Exception {
        AttachmentView v = uploadOk();
        assertTrue(service.accessible(ME, CONV, v.id()).isPresent());
        assertTrue(service.accessible(PEER, CONV, v.id()).isEmpty());
        assertEquals(HttpStatus.NOT_FOUND,
                assertThrows(ApiException.class, () -> service.link(PEER, CONV, v.id())).status());
    }

    // ------------------------------------------------------------ imzali adres

    @Test
    void signedLinkWorksForShortTimeThenExpiresAndCannotBeForged() throws Exception {
        MessageAttachment a = sent(ME, ME, Instant.now());
        AttachmentView.Link link = service.link(PEER, CONV, a.getId());
        assertTrue(link.url().startsWith("/files/p/chat/" + a.getStorageKey() + "?exp="), link.url());
        long exp = Long.parseLong(link.url().replaceAll(".*exp=(\\d+)&.*", "$1"));
        String sig = link.url().replaceAll(".*sig=", "");
        assertTrue(exp <= Instant.now().getEpochSecond() + 301);
        assertTrue(signer.verify("chat", a.getStorageKey(), exp, sig));
        // sure dolmus
        assertFalse(signer.verify("chat", a.getStorageKey(), Instant.now().getEpochSecond() - 1, sig));
        // exp'i uzatmak imzayi bozar
        assertFalse(signer.verify("chat", a.getStorageKey(), exp + 1000, sig));
        // baska dosyaya tasima
        assertFalse(signer.verify("chat", a.getThumbKey(), exp, sig));
    }

    // ------------------------------------------------------------ gizleme / geri alma

    @Test
    void hideClosesAccessKillsOldKeyAndUnhideRestores() throws Exception {
        MessageAttachment a = sent(ME, ME, Instant.now());
        String oldKey = a.getStorageKey();
        AttachmentView.Link link = service.link(PEER, CONV, a.getId());
        assertNotNull(store.read("chat", oldKey));

        service.hide(a.getId());

        assertTrue(a.isHidden());
        assertNotEquals(oldKey, a.getStorageKey());
        assertNull(store.read("chat", oldKey), "eski anahtar (ve imzali adresi) artik bos donmeli");
        assertNotNull(store.read("chat", a.getStorageKey()), "bayt yeni anahtarda saklanmali (geri alinabilir)");
        assertTrue(service.accessible(PEER, CONV, a.getId()).isEmpty());
        assertTrue(service.accessible(ME, CONV, a.getId()).isEmpty());
        assertTrue(link.url().contains(oldKey));
        // gorunum yer tutucu: adres yok
        AttachmentView hv = AttachmentView.of(a);
        assertTrue(hv.removed());
        assertNull(hv.url());
        // yonetici onizlemesi gizli ekte de calisir
        assertEquals(HttpStatus.OK, service.streamForAdmin(a.getId(), false).getStatusCode());
        // idempotent
        String hiddenKey = a.getStorageKey();
        service.hide(a.getId());
        assertEquals(hiddenKey, a.getStorageKey());

        service.unhide(a.getId());
        assertFalse(a.isHidden());
        assertTrue(service.accessible(PEER, CONV, a.getId()).isPresent());
        assertArrayEquals(new byte[] {(byte) 0xFF, (byte) 0xD8}, java.util.Arrays.copyOf(
                store.read("chat", a.getStorageKey()), 2));
    }

    @Test
    void handlerIsReversibleAndPreviewPointsToAdminEndpoint() throws Exception {
        MessageAttachment a = sent(ME, ME, Instant.now());
        MessageImageReportHandler h = new MessageImageReportHandler(repo, service);
        assertTrue(h.reversible());
        assertEquals(edu.bingol.backend.moderation.ReportTargetType.MESSAGE_IMAGE, h.type());
        assertEquals(ME, h.ownerId(a.getId()).orElseThrow());
        var p = h.preview(a.getId()).orElseThrow();
        assertEquals("/api/admin/media/attachments/" + a.getId() + "/preview", p.url());
        assertTrue(p.thumbnailUrl().endsWith("?thumb=true"));
        assertTrue(h.preview(424242L).isEmpty());
        h.hide(a.getId());
        assertTrue(a.isHidden());
        h.unhide(a.getId());
        assertFalse(a.isHidden());
    }

    @Test
    void genericReportEndpointCannotProbeAttachmentsOfOtherConversations() throws Exception {
        MessageAttachment a = sent(ME, ME, Instant.now());
        MessageImageReportHandler h = new MessageImageReportHandler(repo, service);
        when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, OUTSIDER)).thenReturn(Optional.empty());
        var ctx = org.springframework.security.core.context.SecurityContextHolder.createEmptyContext();
        ctx.setAuthentication(new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(
                OUTSIDER, null, List.of()));
        org.springframework.security.core.context.SecurityContextHolder.setContext(ctx);
        try {
            assertFalse(h.exists(a.getId()), "uye olmayan icin 'yok' gibi davranmali");
            ctx.setAuthentication(new org.springframework.security.authentication.UsernamePasswordAuthenticationToken(
                    PEER, null, List.of()));
            assertTrue(h.exists(a.getId()));
        } finally {
            org.springframework.security.core.context.SecurityContextHolder.clearContext();
        }
    }

    // ------------------------------------------------------------ silme / temizlik / KVKK

    @Test
    void deleteUnsentOnlyOwnUnsentUpload() throws Exception {
        AttachmentView v = uploadOk();
        // baskasi silemez (404)
        assertEquals(HttpStatus.NOT_FOUND, assertThrows(ApiException.class,
                () -> service.deleteUnsent(PEER, CONV, v.id())).status());
        // mesaja bagliysa 409
        db.get(v.id()).setMessageId(5L);
        assertEquals("ATTACHMENT_IN_USE", assertThrows(ApiException.class,
                () -> service.deleteUnsent(ME, CONV, v.id())).code());
    }

    @Test
    void cleanupRemovesStaleUnclaimedUploadsAndTheirBlobsOnly() throws Exception {
        AttachmentView stale = uploadOk();
        MessageAttachment s = db.get(stale.id());
        String staleKey = s.getStorageKey();
        when(repo.stale(any(), any())).thenReturn(List.of(s));
        when(repo.deleteIfUnclaimed(s.getId())).thenAnswer(inv -> db.remove(s.getId()) != null ? 1 : 0);
        MessageAttachment kept = sent(ME, ME, Instant.now());

        assertEquals(1, service.cleanup(Duration.ofHours(24)));

        assertNull(store.read("chat", staleKey));
        assertNotNull(store.read("chat", kept.getStorageKey()));
        assertFalse(db.containsKey(s.getId()));
    }

    @Test
    void cleanupDoesNotDeleteBlobWhenAttachmentWasClaimedMeanwhile() throws Exception {
        AttachmentView v = uploadOk();
        MessageAttachment a = db.get(v.id());
        when(repo.stale(any(), any())).thenReturn(List.of(a));
        when(repo.deleteIfUnclaimed(a.getId())).thenReturn(0); // yaris: arada mesaja baglandi
        assertEquals(0, service.cleanup(Duration.ofHours(24)));
        assertNotNull(store.read("chat", a.getStorageKey()));
    }

    @Test
    void purgeForUserRemovesRowsAndBlobs() throws Exception {
        MessageAttachment a = sent(ME, ME, Instant.now());
        when(repo.findByUploaderId(ME)).thenReturn(List.of(a));
        org.mockito.Mockito.doAnswer(inv -> {
            db.remove(((MessageAttachment) inv.getArgument(0)).getId());
            return null;
        }).when(repo).delete(any(MessageAttachment.class));

        assertEquals(1, service.purgeForUser(ME));

        assertNull(store.read("chat", a.getStorageKey()));
        assertTrue(db.isEmpty());
    }

    @Test
    void viewsForGroupsByMessageAndHidesUrlsOfHiddenAttachments() throws Exception {
        MessageAttachment a = sent(ME, ME, Instant.now());
        MessageAttachment b = sent(ME, ME, Instant.now());
        b.setMessageId(a.getMessageId());
        b.setHiddenAt(Instant.now());
        when(repo.findByMessageIdIn(anyCollection())).thenReturn(List.of(b, a));

        List<AttachmentView> list = service.viewsFor(List.of(a.getMessageId())).get(a.getMessageId());

        assertEquals(2, list.size());
        assertEquals(a.getId(), list.get(0).id());
        assertFalse(list.get(0).removed());
        assertTrue(list.get(1).removed());
        assertNull(list.get(1).url());
    }
}
