package edu.bingol.backend.messaging.media;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.config.StorageProperties;
import edu.bingol.backend.crypto.ChunkedAesGcmBlobCipher;
import edu.bingol.backend.crypto.CryptoService;
import edu.bingol.backend.crypto.CryptoTestSupport;
import edu.bingol.backend.crypto.KeyProvider;
import edu.bingol.backend.crypto.MediaBlobCipherAdapter;
import edu.bingol.backend.media.BlobCipher;
import edu.bingol.backend.media.ImageProcessor;
import edu.bingol.backend.media.MediaUrlSigner;
import edu.bingol.backend.media.Mp4Info;
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
import java.io.ByteArrayInputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.multipart.MultipartFile;

/** Video mesaj: dogrulama, poster hatti, Range akisi (duz ve sifreli depo), erisim, 2 video / view-once kurallari. */
class VideoMessageTest {

    static final Long ME = 1L;
    static final Long PEER = 2L;
    static final Long OUTSIDER = 3L;
    static final Long CONV = 10L;

    @TempDir
    Path dir;

    final Map<Long, MessageAttachment> db = new HashMap<>();
    final Map<Long, Message> messageDb = new HashMap<>();
    final AtomicLong seq = new AtomicLong(100);
    final MessageAttachmentRepository repo = mock(MessageAttachmentRepository.class);
    final ConversationRepository convs = mock(ConversationRepository.class);
    final ConversationMemberRepository members = mock(ConversationMemberRepository.class);
    final MessageRepository messages = mock(MessageRepository.class);
    final UserRepository users = mock(UserRepository.class);
    final BlockService blocks = mock(BlockService.class);
    final RateLimiter limiter = mock(RateLimiter.class);
    final ContentBlocklist blocklist = mock(ContentBlocklist.class);

    PrivateMediaStore store;
    MessageAttachmentService service;

    @BeforeEach
    void setUp() {
        init(false);
    }

    @SuppressWarnings("unchecked")
    void init(boolean encrypted) {
        MediaProperties props = new MediaProperties(0, 4, 0, 0, 0, null, null, null, null, true, null, null, null, null);
        KeyProvider kp = CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(7), "");
        ObjectProvider<BlobCipher> cipher = mock(ObjectProvider.class);
        when(cipher.getIfAvailable(any())).thenReturn(new MediaBlobCipherAdapter(kp, new CryptoService()));
        store = new PrivateMediaStore(new StorageProperties(dir.toString()), props, new ImageProcessor(props), cipher);
        if (encrypted) {
            CryptoTestSupport t = new CryptoTestSupport();
            store.setStreamCipher(new ChunkedAesGcmBlobCipher(t.keyService(kp), t.crypto));
        }
        MediaUrlSigner signer = new MediaUrlSigner(props, "test-secret-test-secret-test-secret-1234");
        service = new MessageAttachmentService(repo, convs, members, messages, users, blocks, limiter, store, signer,
                props, blocklist, 20, 200, 10, 30, 300);

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
            Iterable<Long> given = inv.getArgument(0);
            for (Long id : given == null ? List.<Long>of() : given) {
                if (db.containsKey(id)) {
                    out.add(db.get(id));
                }
            }
            return out;
        });
        when(repo.existsByStorageKey(anyString())).thenAnswer(inv ->
                db.values().stream().anyMatch(a -> a.getStorageKey().equals(inv.getArgument(0))));

        Conversation conv = new Conversation();
        conv.setId(CONV);
        conv.setType(Conversation.Type.DIRECT);
        when(convs.findById(CONV)).thenReturn(Optional.of(conv));
        for (Long id : List.of(ME, PEER)) {
            when(members.findByConversationIdAndUserIdAndLeftAtIsNull(CONV, id))
                    .thenReturn(Optional.of(ConversationMember.of(CONV, id, ConversationMember.Role.MEMBER)));
        }
        when(members.findByConversationIdAndLeftAtIsNullOrderByJoinedAtAscIdAsc(CONV)).thenReturn(List.of(
                ConversationMember.of(CONV, ME, ConversationMember.Role.MEMBER),
                ConversationMember.of(CONV, PEER, ConversationMember.Role.MEMBER)));
        for (Long id : List.of(ME, PEER, OUTSIDER)) {
            User u = new User();
            u.setId(id);
            when(users.findById(id)).thenReturn(Optional.of(u));
        }
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
    }

    static MultipartFile video(byte[] data) {
        return new MockMultipartFile("file", "v.mp4", "video/mp4", data);
    }

    static MultipartFile poster() throws Exception {
        return new MockMultipartFile("poster", "p.png", "image/png", MessageAttachmentServiceTest.png(1920, 1080));
    }

    /** Yuklenen videoyu ME'nin mesajina baglar (okuma yetkisi icin). */
    MessageAttachment sent(AttachmentView v) {
        MessageAttachment a = db.get(v.id());
        Message m = new Message();
        m.setId(900L + a.getId());
        m.setConversationId(CONV);
        m.setSenderId(ME);
        m.setCreatedAt(Instant.now());
        messageDb.put(m.getId(), m);
        when(messages.findById(m.getId())).thenReturn(Optional.of(m));
        a.setMessageId(m.getId());
        return a;
    }

    MockHttpServletResponse get(Long user, Long aid, String range) {
        MockHttpServletResponse resp = new MockHttpServletResponse();
        assertNull(service.serve(user, CONV, aid, false, range, resp));
        return resp;
    }

    // ------------------------------------------------------------ Mp4Info

    @Test
    void mp4InfoParsesBothVersionsAndRejectsGarbage() throws Exception {
        Mp4Info.Info v0 = Mp4Info.parse(Mp4Fixtures.mp4(12.5, 640, 360, 1000));
        assertEquals(12_500, v0.durationMs());
        assertEquals(640, v0.width());
        assertEquals(360, v0.height());
        Mp4Info.Info v1 = Mp4Info.parse(Mp4Fixtures.mp4(1, 90_000, 450_000, 1280, 720, 100));
        assertEquals(5_000, v1.durationMs());
        assertEquals(1280, v1.width());

        assertThrows(Mp4Info.Invalid.class, () -> Mp4Info.parse(new byte[100]));
        byte[] noMoov = Arrays.copyOf(Mp4Fixtures.mp4(1, 10, 10, 50), 60); // moov kesik
        assertThrows(Mp4Info.Invalid.class, () -> Mp4Info.parse(noMoov));
        assertThrows(Mp4Info.Invalid.class, () -> Mp4Info.parse(Mp4Fixtures.mp4(0, 0, 0, 0, 0, 10))); // timescale 0
    }

    // ------------------------------------------------------------ yukleme

    @Test
    void validVideoIsStoredWithMetaAndNoPosterMeansNullThumb() throws Exception {
        byte[] mp4 = Mp4Fixtures.mp4(7.2, 640, 360, 5000);
        AttachmentView v = service.upload(ME, CONV, video(mp4), null);

        assertEquals("VIDEO", v.kind());
        assertEquals(7_200, v.durationMs());
        assertEquals(mp4.length, v.sizeBytes());
        assertEquals(mp4.length, v.bytes());
        assertEquals(640, v.width());
        assertEquals(360, v.height());
        assertEquals("video/mp4", v.contentType());
        assertNull(v.thumbUrl());
        assertNotNull(v.url());
        assertFalse(v.viewOnce());
        assertThrows(ApiException.class, () -> service.stream(ME, CONV, v.id(), true)); // posterSiz -> 404
    }

    @Test
    void posterGoesThroughImagePipelineAndIsServedAsThumb() throws Exception {
        AttachmentView v = service.upload(ME, CONV, video(Mp4Fixtures.mp4(3, 1920, 1080, 2000)), poster());
        sent(v);

        assertNotNull(v.thumbUrl());
        assertTrue(v.width() <= 720 && v.height() <= 720, v.width() + "x" + v.height());
        assertEquals(720, v.width());
        var thumb = service.stream(ME, CONV, v.id(), true);
        assertEquals("image/jpeg", String.valueOf(thumb.getHeaders().getContentType()));
        byte[] jpg = thumb.getBody().getContentAsByteArray();
        assertEquals((byte) 0xFF, jpg[0]);
        assertEquals(720, ImageIO.read(new ByteArrayInputStream(jpg)).getWidth());
    }

    @Test
    void tooLongTooLargeAndCorruptAreRejected() throws Exception {
        ApiException longE = assertThrows(ApiException.class,
                () -> service.upload(ME, CONV, video(Mp4Fixtures.mp4(61, 640, 360, 100)), null));
        assertEquals("VIDEO_TOO_LONG", longE.code());
        assertEquals(400, longE.status().value());
        service.upload(ME, CONV, video(Mp4Fixtures.mp4(60, 640, 360, 100)), null); // sinir: kabul

        ReflectionTestUtils.setField(service, "videoMaxBytes", 1000L);
        ApiException big = assertThrows(ApiException.class,
                () -> service.upload(ME, CONV, video(Mp4Fixtures.mp4(1, 64, 64, 5000)), null));
        assertEquals("VIDEO_TOO_LARGE", big.code());
        assertEquals(413, big.status().value());
        ReflectionTestUtils.setField(service, "videoMaxBytes", 40L << 20);

        for (byte[] bad : new byte[][] {new byte[0], new byte[500], "<html>not a video at all..</html>".getBytes(),
                Arrays.copyOf(Mp4Fixtures.mp4(1, 64, 64, 100), 40)}) {
            ApiException e = assertThrows(ApiException.class, () -> service.upload(ME, CONV, video(bad), null));
            assertEquals("VIDEO_INVALID", e.code());
        }
        // content-type video/mp4 degil
        ApiException ct = assertThrows(ApiException.class, () -> service.upload(ME, CONV,
                new MockMultipartFile("file", "v.mp4", "video/webm", Mp4Fixtures.mp4(1, 64, 64, 100)), null));
        assertEquals("VIDEO_INVALID", ct.code());
        // her red sonrasi diskte yetim video kalmamali
        assertEquals(1, db.size());
    }

    @Test
    void dailyVideoQuotaIsChecked() throws Exception {
        org.mockito.Mockito.doThrow(new ApiException(org.springframework.http.HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "x"))
                .when(limiter).check(org.mockito.ArgumentMatchers.startsWith("chatvideo:day:"), org.mockito.ArgumentMatchers.anyInt(), any());
        ApiException e = assertThrows(ApiException.class,
                () -> service.upload(ME, CONV, video(Mp4Fixtures.mp4(1, 64, 64, 100)), null));
        assertEquals(429, e.status().value());
    }

    // ------------------------------------------------------------ Range akisi

    private void rangeScenario() throws Exception {
        byte[] mp4 = Mp4Fixtures.mp4(10, 640, 360, 300_000); // 64 KB parcalarin birkacini kapsar
        AttachmentView v = service.upload(ME, CONV, video(mp4), null);
        sent(v);

        MockHttpServletResponse full = get(PEER, v.id(), null);
        assertEquals(200, full.getStatus());
        assertEquals("bytes", full.getHeader("Accept-Ranges"));
        assertEquals("video/mp4", full.getContentType());
        assertEquals(String.valueOf(mp4.length), full.getHeader("Content-Length"));
        assertArrayEquals(mp4, full.getContentAsByteArray());
        assertTrue(full.getHeader("Cache-Control").contains("no-store"));

        MockHttpServletResponse part = get(PEER, v.id(), "bytes=10-19");
        assertEquals(206, part.getStatus());
        assertEquals("bytes 10-19/" + mp4.length, part.getHeader("Content-Range"));
        assertEquals("10", part.getHeader("Content-Length"));
        assertArrayEquals(Arrays.copyOfRange(mp4, 10, 20), part.getContentAsByteArray());

        // parca sinirini asan, ortadan baslayan aralik
        MockHttpServletResponse mid = get(PEER, v.id(), "bytes=65000-140000");
        assertEquals(206, mid.getStatus());
        assertArrayEquals(Arrays.copyOfRange(mp4, 65000, 140001), mid.getContentAsByteArray());

        MockHttpServletResponse open = get(PEER, v.id(), "bytes=" + (mp4.length - 100) + "-");
        assertEquals("bytes " + (mp4.length - 100) + "-" + (mp4.length - 1) + "/" + mp4.length, open.getHeader("Content-Range"));
        assertArrayEquals(Arrays.copyOfRange(mp4, mp4.length - 100, mp4.length), open.getContentAsByteArray());

        MockHttpServletResponse suffix = get(PEER, v.id(), "bytes=-5");
        assertEquals(206, suffix.getStatus());
        assertArrayEquals(Arrays.copyOfRange(mp4, mp4.length - 5, mp4.length), suffix.getContentAsByteArray());

        // sondan tasan bitis kirpilir
        MockHttpServletResponse clip = get(PEER, v.id(), "bytes=" + (mp4.length - 3) + "-" + (mp4.length + 500));
        assertEquals(206, clip.getStatus());
        assertEquals(3, clip.getContentAsByteArray().length);

        MockHttpServletResponse bad = get(PEER, v.id(), "bytes=" + mp4.length + "-");
        assertEquals(416, bad.getStatus());
        assertEquals("bytes */" + mp4.length, bad.getHeader("Content-Range"));
        assertEquals(416, get(PEER, v.id(), "bytes=garbage").getStatus());
    }

    @Test
    void rangeOnPlainStore() throws Exception {
        rangeScenario();
    }

    @Test
    void rangeOnEncryptedStoreAndBytesAreEncryptedOnDisk() throws Exception {
        init(true);
        rangeScenario();
        Path bucket = dir.resolve("_private").resolve("chat");
        try (var files = Files.list(bucket)) {
            Path mp4 = files.filter(f -> f.toString().endsWith(".mp4")).findFirst().orElseThrow();
            byte[] head = Arrays.copyOf(Files.readAllBytes(mp4), 4);
            assertArrayEquals("BUB1".getBytes(), head); // ftyp degil: diskte sifreli
        }
    }

    @Test
    void outsiderAndUnsentUploadsCannotStream() throws Exception {
        AttachmentView v = service.upload(ME, CONV, video(Mp4Fixtures.mp4(2, 64, 64, 100)), null);
        // gonderilmemis yukleme yalniz sahibine
        assertEquals("ATTACHMENT_NOT_FOUND",
                assertThrows(ApiException.class, () -> get(PEER, v.id(), null)).code());
        assertEquals(200, get(ME, v.id(), null).getStatus());
        sent(v);
        assertEquals(206, get(PEER, v.id(), "bytes=0-3").getStatus());
        assertThrows(ApiException.class, () -> get(OUTSIDER, v.id(), null));
    }

    // ------------------------------------------------------------ mesaj kurallari

    @Test
    void manyVideosMixedWithImagesAllowedUntilTotalBytesExceeded() throws Exception {
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            ids.add(service.upload(ME, CONV, video(Mp4Fixtures.mp4(2, 64, 64, 2000)), null).id());
        }
        ids.add(service.upload(ME, CONV, new MockMultipartFile("file", "i.png", "image/png",
                MessageAttachmentServiceTest.png(100, 100)), null).id());
        assertEquals(ids, service.precheck(ME, CONV, ids)); // 5 video + 1 foto karisik, tek sinir bayt toplami

        ReflectionTestUtils.setField(service, "videoMaxTotalBytes", 5000L);
        ApiException e = assertThrows(ApiException.class, () -> service.precheck(ME, CONV, ids));
        assertEquals("MESSAGE_MEDIA_TOO_LARGE", e.code());
        assertEquals(413, e.status().value());
    }

    @Test
    void tenAttachmentsAcceptedElevenRejected() throws Exception {
        MessageAttachmentService svc = new MessageAttachmentService(repo, convs, members, messages, users, blocks, limiter,
                store, new MediaUrlSigner(new MediaProperties(0, 4, 0, 0, 0, null, null, null, null, true, null, null, null, null),
                "test-secret-test-secret-test-secret-1234"),
                new MediaProperties(0, 4, 0, 0, 0, null, null, null, null, true, null, null, null, null), blocklist,
                20, 200, 10, 30, 300);
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < 11; i++) {
            ids.add(svc.upload(ME, CONV, new MockMultipartFile("file", "i.png", "image/png",
                    MessageAttachmentServiceTest.png(60 + i, 60)), null).id());
        }
        assertEquals(10, svc.precheck(ME, CONV, ids.subList(0, 10)).size());
        assertEquals("ATTACHMENT_LIMIT", assertThrows(ApiException.class, () -> svc.precheck(ME, CONV, ids)).code());
    }

    @Test
    void viewOnceVideoIsRejectedByPrecheck() throws Exception {
        AttachmentView a = service.upload(ME, CONV, video(Mp4Fixtures.mp4(2, 64, 64, 100)), null);
        AttachmentView b = service.upload(ME, CONV, video(Mp4Fixtures.mp4(2, 64, 64, 100)), null);
        assertNotNull(b);
        AttachmentView img = service.upload(ME, CONV, new MockMultipartFile("file", "i.png", "image/png",
                MessageAttachmentServiceTest.png(100, 100)), null);

        assertEquals("VIEW_ONCE_INVALID", assertThrows(ApiException.class,
                () -> service.precheck(ME, CONV, List.of(a.id()), true)).code());
        // video + gorsel karisik gonderilebilir
        assertEquals(List.of(a.id(), img.id()), service.precheck(ME, CONV, List.of(a.id(), img.id())));
        assertEquals("IMAGE", img.kind());
    }

    // ------------------------------------------------------------ yasam dongusu

    @Test
    void linkForVideoHasNoBodyUrlButPosterUrl() throws Exception {
        AttachmentView v = service.upload(ME, CONV, video(Mp4Fixtures.mp4(2, 64, 64, 100)), poster());
        sent(v);
        AttachmentView.Link link = service.link(ME, CONV, v.id());
        assertNull(link.url());
        assertNotNull(link.thumbUrl());
    }

    @Test
    void hideMovesVideoAndPosterToNewKeysAndStaysStreamableForAdmin() throws Exception {
        init(true);
        byte[] mp4 = Mp4Fixtures.mp4(2, 64, 64, 100_000);
        AttachmentView v = service.upload(ME, CONV, video(mp4), poster());
        MessageAttachment a = sent(v);
        String oldKey = a.getStorageKey();
        String oldThumb = a.getThumbKey();

        service.hide(a.getId());

        assertNotEquals(oldKey, a.getStorageKey());
        assertNotEquals(oldThumb, a.getThumbKey());
        assertThrows(ApiException.class, () -> get(PEER, a.getId(), null)); // gizli: erisim kapali
        MockHttpServletResponse admin = new MockHttpServletResponse();
        assertNull(service.streamForAdmin(a.getId(), false, "bytes=0-9", admin));
        assertEquals(206, admin.getStatus());
        assertArrayEquals(Arrays.copyOf(mp4, 10), admin.getContentAsByteArray());
        assertFalse(Files.exists(dir.resolve("_private").resolve("chat").resolve(oldKey)));
        assertEquals(2, countFiles()); // yalniz yeni video + yeni poster
    }

    @Test
    void deletingUnsentVideoRemovesVideoAndPosterFiles() throws Exception {
        AttachmentView v = service.upload(ME, CONV, video(Mp4Fixtures.mp4(2, 64, 64, 100)), poster());
        assertEquals(2, countFiles());
        service.deleteUnsent(ME, CONV, v.id());
        assertEquals(0, countFiles());
    }

    @Test
    void messageDeletionPurgesVideoFiles() throws Exception {
        AttachmentView v = service.upload(ME, CONV, video(Mp4Fixtures.mp4(2, 64, 64, 100)), poster());
        MessageAttachment a = sent(v);
        when(repo.findByMessageId(a.getMessageId())).thenReturn(List.of(a));
        service.purgeForMessage(a.getMessageId());
        assertEquals(0, countFiles());
    }

    @Test
    void viewIsRemovedWhenHiddenButKeepsKindAndDuration() throws Exception {
        AttachmentView v = service.upload(ME, CONV, video(Mp4Fixtures.mp4(4, 64, 64, 100)), null);
        MessageAttachment a = sent(v);
        a.setHiddenAt(Instant.now());
        AttachmentView hidden = AttachmentView.of(a);
        assertTrue(hidden.removed());
        assertEquals("VIDEO", hidden.kind());
        assertEquals(4_000, hidden.durationMs());
        assertNull(hidden.url());
    }

    private long countFiles() throws Exception {
        Path bucket = dir.resolve("_private").resolve("chat");
        if (!Files.isDirectory(bucket)) {
            return 0;
        }
        try (var s = Files.list(bucket)) {
            return s.filter(f -> !f.getFileName().toString().startsWith(".tmp")).count();
        }
    }

    private static void assertNotEquals(Object a, Object b) {
        org.junit.jupiter.api.Assertions.assertNotEquals(a, b);
    }
}
