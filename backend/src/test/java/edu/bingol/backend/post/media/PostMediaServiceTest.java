package edu.bingol.backend.post.media;

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
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimitedException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.config.StorageProperties;
import edu.bingol.backend.crypto.CryptoService;
import edu.bingol.backend.crypto.CryptoTestSupport;
import edu.bingol.backend.crypto.KeyProvider;
import edu.bingol.backend.crypto.MediaBlobCipherAdapter;
import edu.bingol.backend.media.BlobCipher;
import edu.bingol.backend.media.ImageProcessor;
import edu.bingol.backend.media.NoopBlobCipher;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.messaging.media.Mp4Fixtures;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ContentBlocklist;
import edu.bingol.backend.post.PostDeletedEvent;
import edu.bingol.backend.post.PostDtos.MediaView;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
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
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

/** Gonderi medyasi: yukleme dogrulamalari, Range, yetki, baglama kurallari, supurucu, silme olayi. */
class PostMediaServiceTest {

    static final Long ME = 1L;
    static final Long OTHER = 2L;
    static final Long POST = 500L;

    @TempDir
    Path dir;

    final Map<Long, PostMedia> db = new HashMap<>();
    final Map<Long, PostMediaRepository.PostState> posts = new HashMap<>();
    final AtomicLong seq = new AtomicLong(100);
    final PostMediaRepository repo = mock(PostMediaRepository.class);
    final ContentBlocklist blocklist = mock(ContentBlocklist.class);
    final BlockService blocks = mock(BlockService.class);
    final RateLimiter limiter = mock(RateLimiter.class);

    PrivateMediaStore store;
    PostMediaService service;
    Set<Long> blockedForOther = Set.of();

    @BeforeEach
    void setUp() {
        init(false);
    }

    @SuppressWarnings("unchecked")
    void init(boolean encrypted) {
        MediaProperties props = new MediaProperties(0, 4, 0, 0, 0, null, null, null, null, true, null, null, null, null);
        ObjectProvider<BlobCipher> cipher = mock(ObjectProvider.class);
        if (encrypted) {
            KeyProvider kp = CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(7), "");
            when(cipher.getIfAvailable(any())).thenReturn(new MediaBlobCipherAdapter(kp, new CryptoService()));
        } else {
            when(cipher.getIfAvailable(any())).thenReturn(new NoopBlobCipher());
        }
        store = new PrivateMediaStore(new StorageProperties(dir.toString()), props, new ImageProcessor(props), cipher);
        service = new PostMediaService(repo, store, props, blocklist, blocks, limiter);

        when(repo.save(any(PostMedia.class))).thenAnswer(inv -> {
            PostMedia m = inv.getArgument(0);
            if (m.getId() == null) {
                m.setId(seq.incrementAndGet());
            }
            db.put(m.getId(), m);
            return m;
        });
        when(repo.findById(anyLong())).thenAnswer(inv -> Optional.ofNullable(db.get(inv.<Long>getArgument(0))));
        when(repo.findAllById(any())).thenAnswer(inv -> {
            List<PostMedia> out = new ArrayList<>();
            Iterable<Long> given = inv.getArgument(0);
            for (Long id : given == null ? List.<Long>of() : given) {
                if (db.containsKey(id)) {
                    out.add(db.get(id));
                }
            }
            return out;
        });
        when(repo.findByPostIdIn(any())).thenAnswer(inv -> {
            java.util.Collection<Long> ids = inv.getArgument(0);
            return db.values().stream().filter(m -> m.getPostId() != null && ids.contains(m.getPostId())).toList();
        });
        when(repo.findByPostIdOrderByPositionAscIdAsc(anyLong())).thenAnswer(inv -> db.values().stream()
                .filter(m -> inv.<Long>getArgument(0).equals(m.getPostId()))
                .sorted(java.util.Comparator.comparing(PostMedia::getPosition)).toList());
        when(repo.findByOwnerId(anyLong())).thenAnswer(inv -> db.values().stream()
                .filter(m -> m.getOwnerId().equals(inv.<Long>getArgument(0))).toList());
        when(repo.countByOwnerIdAndPostIdIsNullAndStoryIdIsNull(anyLong())).thenAnswer(inv -> db.values().stream()
                .filter(m -> m.getOwnerId().equals(inv.<Long>getArgument(0)) && m.getPostId() == null).count());
        when(repo.existsByStorageKey(anyString())).thenAnswer(inv -> db.values().stream()
                .anyMatch(m -> m.getStorageKey().equals(inv.getArgument(0))));
        when(repo.bind(anyLong(), anyLong(), anyLong(), anyShort())).thenAnswer(inv -> {
            PostMedia m = db.get(inv.<Long>getArgument(0));
            if (m == null || !m.getOwnerId().equals(inv.<Long>getArgument(1)) || m.getPostId() != null || m.isHidden()) {
                return 0;
            }
            m.setPostId(inv.getArgument(2));
            m.setPosition(inv.<Short>getArgument(3));
            return 1;
        });
        when(repo.hideByPost(anyLong(), any(Instant.class))).thenAnswer(inv -> {
            db.values().stream().filter(m -> inv.<Long>getArgument(0).equals(m.getPostId()))
                    .forEach(m -> m.setHiddenAt(Instant.now()));
            return 1;
        });
        when(repo.unhideByPost(anyLong())).thenAnswer(inv -> {
            db.values().stream().filter(m -> inv.<Long>getArgument(0).equals(m.getPostId()))
                    .forEach(m -> m.setHiddenAt(null));
            return 1;
        });
        when(repo.stale(any(Instant.class), any())).thenAnswer(inv -> db.values().stream()
                .filter(m -> m.getPostId() == null && m.getCreatedAt().isBefore(inv.getArgument(0))).toList());
        when(repo.deleteIfUnattached(anyLong())).thenAnswer(inv -> {
            PostMedia m = db.get(inv.<Long>getArgument(0));
            if (m != null && m.getPostId() == null) {
                db.remove(m.getId());
                return 1;
            }
            return 0;
        });
        when(repo.ofPostsDeletedBefore(any(Instant.class), any())).thenAnswer(inv -> db.values().stream()
                .filter(m -> m.getPostId() != null && posts.containsKey(m.getPostId())
                        && posts.get(m.getPostId()).getDeletedAt() != null
                        && posts.get(m.getPostId()).getDeletedAt().isBefore(inv.getArgument(0))).toList());
        org.mockito.Mockito.doAnswer(inv -> {
            db.remove(inv.<PostMedia>getArgument(0).getId());
            return null;
        }).when(repo).delete(any(PostMedia.class));
        when(repo.postState(anyLong())).thenAnswer(inv -> Optional.ofNullable(posts.get(inv.<Long>getArgument(0))));

        when(blocks.hiddenFrom(any())).thenAnswer(inv -> OTHER.equals(inv.getArgument(0)) ? blockedForOther : Set.of());
        when(blocklist.isBlocked(anyString())).thenReturn(false);
        post(POST, ME, null, null);
    }

    static short anyShort() {
        return org.mockito.ArgumentMatchers.anyShort();
    }

    void post(Long id, Long author, Instant deletedAt, Instant hiddenAt) {
        posts.put(id, new PostMediaRepository.PostState() {
            public Long getAuthorId() {
                return author;
            }

            public Instant getDeletedAt() {
                return deletedAt;
            }

            public Instant getHiddenAt() {
                return hiddenAt;
            }
        });
    }

    // ---------------------------------------------------------------- yardimcilar

    static byte[] jpeg(int w, int h) throws Exception {
        BufferedImage img = new BufferedImage(w, h, BufferedImage.TYPE_INT_RGB);
        for (int x = 0; x < w; x++) {
            for (int y = 0; y < h; y++) {
                img.setRGB(x, y, ((x * 255 / w) << 16) | ((y * 255 / h) << 8) | 0x40);
            }
        }
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(img, "jpg", out);
        return out.toByteArray();
    }

    static MultipartFile imageFile(byte[] data) {
        return new MockMultipartFile("file", "a.jpg", "image/jpeg", data);
    }

    static MultipartFile videoFile(byte[] data) {
        return new MockMultipartFile("file", "v.mp4", "video/mp4", data);
    }

    PostMediaService.Uploaded uploadImage(Long user) throws Exception {
        return service.upload(user, imageFile(jpeg(300, 200)), null);
    }

    PostMediaService.Uploaded uploadVideo(Long user, boolean poster) throws Exception {
        MultipartFile p = poster ? new MockMultipartFile("poster", "p.jpg", "image/jpeg", jpeg(640, 360)) : null;
        return service.upload(user, videoFile(Mp4Fixtures.mp4(5.0, 640, 360, 4096)), p);
    }

    static void assertApi(HttpStatus status, String code, Runnable r) {
        ApiException e = assertThrows(ApiException.class, r::run);
        assertEquals(status, e.status());
        assertEquals(code, e.code());
    }

    long fileCount() throws Exception {
        Path d = dir.resolve("_private").resolve("post");
        if (!Files.isDirectory(d)) {
            return 0;
        }
        try (Stream<Path> s = Files.list(d)) {
            return s.count();
        }
    }

    // ---------------------------------------------------------------- gorsel yukleme

    @Test
    void imageUploadResizesAndMakesThumb() throws Exception {
        PostMediaService.Uploaded u = service.upload(ME, imageFile(jpeg(3000, 1500)), null);
        assertEquals("IMAGE", u.kind());
        assertEquals(1600, u.width());
        assertEquals(800, u.height());
        assertEquals("/api/posts/media/" + u.id(), u.url());
        assertEquals("/api/posts/media/" + u.id() + "?thumb=true", u.thumbUrl());
        assertNull(u.durationMs());
        PostMedia m = db.get(u.id());
        assertEquals(ME, m.getOwnerId());
        assertNull(m.getPostId());
        assertEquals(64, m.getSha256().length());
        BufferedImage thumb = ImageIO.read(new ByteArrayInputStream(store.read("post", m.getThumbKey())));
        assertEquals(480, Math.max(thumb.getWidth(), thumb.getHeight()));
        BufferedImage main = ImageIO.read(new ByteArrayInputStream(store.read("post", m.getStorageKey())));
        assertEquals(1600, main.getWidth());
        assertEquals(2, fileCount());
    }

    @Test
    void imageIsReencodedWithoutExifAndSvgIsRejected() throws Exception {
        byte[] j = jpeg(200, 200);
        // APP1 "Exif" bolumu ekle
        byte[] exif = "Exif\0\0GPSLATITUDE-SECRET".getBytes(StandardCharsets.ISO_8859_1);
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        o.write(j, 0, 2);
        o.write(0xFF);
        o.write(0xE1);
        o.write((exif.length + 2) >> 8);
        o.write((exif.length + 2) & 0xFF);
        o.write(exif);
        o.write(j, 2, j.length - 2);
        PostMediaService.Uploaded u = service.upload(ME, imageFile(o.toByteArray()), null);
        byte[] stored = store.read("post", db.get(u.id()).getStorageKey());
        assertFalse(new String(stored, StandardCharsets.ISO_8859_1).contains("GPSLATITUDE"));
        assertThrows(ApiException.class, () -> service.upload(ME, new MockMultipartFile("file", "a.svg",
                "image/svg+xml", "<svg/>".getBytes()), null));
        assertThrows(ApiException.class, () -> service.upload(ME, new MockMultipartFile("file", "a.jpg",
                "image/jpeg", "bu bir gorsel degil, duz metin".getBytes()), null));
    }

    @Test
    void blockedHashIsRejected() throws Exception {
        byte[] raw = jpeg(100, 100);
        when(blocklist.isBlocked(PostMediaService.sha256Hex(raw))).thenReturn(true);
        assertApi(HttpStatus.UNPROCESSABLE_ENTITY, "MEDIA_BLOCKED", () -> service.upload(ME, imageFile(raw), null));
        assertEquals(0, db.size());
        assertEquals(0, fileCount());
    }

    @Test
    void blockedReencodedOutputIsRejectedAndNothingWritten() throws Exception {
        // ham ozet temiz, yeniden kodlanmis cikti yasakli
        when(blocklist.isBlocked(anyString())).thenReturn(false).thenReturn(true);
        assertApi(HttpStatus.UNPROCESSABLE_ENTITY, "MEDIA_BLOCKED",
                () -> service.upload(ME, imageFile(unchecked(() -> jpeg(100, 100))), null));
        assertEquals(0, fileCount());
    }

    interface Thrower<T> {
        T get() throws Exception;
    }

    static <T> T unchecked(Thrower<T> t) {
        try {
            return t.get();
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    // ---------------------------------------------------------------- kota

    @Test
    void hourlyRateLimitIsAppliedAndPendingCapEnforced() throws Exception {
        uploadImage(ME);
        org.mockito.Mockito.verify(limiter).check("postmedia:hour:" + ME, 30, Duration.ofHours(1));
        doThrow(new RateLimitedException(60)).when(limiter).check(anyString(), org.mockito.ArgumentMatchers.anyInt(),
                any(Duration.class));
        assertThrows(RateLimitedException.class, () -> unchecked(() -> uploadImage(ME)));
    }

    @Test
    void pendingCapBlocksUploadsButBoundMediaDoesNotCount() throws Exception {
        service.setPendingMax(2);
        PostMediaService.Uploaded a = uploadImage(ME);
        uploadImage(ME);
        assertApi(HttpStatus.TOO_MANY_REQUESTS, "POST_MEDIA_PENDING_LIMIT", () -> unchecked(() -> uploadImage(ME)));
        service.attach(POST, ME, List.of(a.id()));
        uploadImage(ME); // bir tanesi baglandi, yer acildi
        uploadImage(OTHER); // baska kullanicinin kotasi ayri
    }

    // ---------------------------------------------------------------- video

    @Test
    void videoUploadStoresPlainWithPoster() throws Exception {
        byte[] raw = Mp4Fixtures.mp4(12.0, 1280, 720, 8192);
        PostMediaService.Uploaded u = service.upload(ME, videoFile(raw),
                new MockMultipartFile("poster", "p.png", "image/jpeg", jpeg(1920, 1080)));
        assertEquals("VIDEO", u.kind());
        assertEquals(12000, u.durationMs());
        assertEquals(raw.length, u.bytes());
        assertNotNull(u.thumbUrl());
        PostMedia m = db.get(u.id());
        assertTrue(m.getThumbKey().endsWith(".jpg") || m.getThumbKey().endsWith(".png"));
        assertEquals(720, Math.max(m.getWidth(), m.getHeight()));
        // duz saklanir (konusma DEK'i yok) ve /files/** disinda
        assertArrayEquals(raw, Files.readAllBytes(dir.resolve("_private").resolve("post").resolve(m.getStorageKey())));
        assertFalse(Files.exists(dir.resolve("posts")));
    }

    @Test
    void videoWithoutPosterHasNoThumb() throws Exception {
        PostMediaService.Uploaded u = uploadVideo(ME, false);
        assertNull(u.thumbUrl());
        assertEquals(640, u.width());
        assertEquals(360, u.height());
        MockHttpServletResponse resp = new MockHttpServletResponse();
        assertApi(HttpStatus.NOT_FOUND, "POST_MEDIA_NOT_FOUND",
                () -> service.serve(ME, u.id(), true, null, null, resp));
    }

    @Test
    void videoValidations() throws Exception {
        assertApi(HttpStatus.BAD_REQUEST, "VIDEO_TOO_LONG",
                () -> service.upload(ME, videoFile(Mp4Fixtures.mp4(61.0, 320, 240, 100)), null));
        service.upload(ME, videoFile(Mp4Fixtures.mp4(60.0, 320, 240, 100)), null); // sinirda gecer
        service.setVideoLimits(1000, 60);
        assertApi(HttpStatus.PAYLOAD_TOO_LARGE, "VIDEO_TOO_LARGE",
                () -> service.upload(ME, videoFile(Mp4Fixtures.mp4(5.0, 320, 240, 5000)), null));
        service.setVideoLimits(40L << 20, 60);
        byte[] junk = new byte[64];
        assertApi(HttpStatus.BAD_REQUEST, "VIDEO_INVALID", () -> service.upload(ME, videoFile(junk), null));
        byte[] ftypOnly = Arrays.copyOf(Mp4Fixtures.mp4(5.0, 320, 240, 10), 24); // moov kesik
        assertApi(HttpStatus.BAD_REQUEST, "VIDEO_INVALID", () -> service.upload(ME, videoFile(ftypOnly), null));
        assertApi(HttpStatus.BAD_REQUEST, "VIDEO_INVALID", () -> service.upload(ME,
                new MockMultipartFile("file", "v.mp4", "video/quicktime", Mp4Fixtures.mp4(5.0, 320, 240, 10)), null));
        assertApi(HttpStatus.BAD_REQUEST, "VIDEO_INVALID", () -> service.upload(ME,
                new MockMultipartFile("file", "v.mp4", "video/mp4", new byte[0]), null));
        assertEquals(1, db.size());
    }

    @Test
    void videoBlockedHashIsRejected() throws Exception {
        byte[] raw = Mp4Fixtures.mp4(5.0, 320, 240, 100);
        when(blocklist.isBlocked(PostMediaService.sha256Hex(raw))).thenReturn(true);
        assertApi(HttpStatus.UNPROCESSABLE_ENTITY, "MEDIA_BLOCKED", () -> service.upload(ME, videoFile(raw), null));
        assertEquals(0, fileCount());
    }

    // ---------------------------------------------------------------- sunum, Range

    @Test
    void rangeResponses200_206_416() throws Exception {
        byte[] raw = Mp4Fixtures.mp4(5.0, 320, 240, 5000);
        PostMediaService.Uploaded u = service.upload(ME, videoFile(raw), null);
        long len = raw.length;

        MockHttpServletResponse full = new MockHttpServletResponse();
        assertNull(service.serve(ME, u.id(), false, null, null, full));
        assertEquals(200, full.getStatus());
        assertEquals("bytes", full.getHeader("Accept-Ranges"));
        String cc = full.getHeader("Cache-Control");
        assertTrue(cc != null && cc.contains("private") && cc.contains("max-age=86400"), cc);
        assertNotNull(full.getHeader("ETag"));
        assertArrayEquals(raw, full.getContentAsByteArray());

        MockHttpServletResponse part = new MockHttpServletResponse();
        assertNull(service.serve(ME, u.id(), false, "bytes=100-299", null, part));
        assertEquals(206, part.getStatus());
        assertEquals("bytes 100-299/" + len, part.getHeader("Content-Range"));
        assertEquals("200", part.getHeader("Content-Length"));
        assertArrayEquals(Arrays.copyOfRange(raw, 100, 300), part.getContentAsByteArray());

        MockHttpServletResponse open = new MockHttpServletResponse();
        service.serve(ME, u.id(), false, "bytes=" + (len - 50) + "-", null, open);
        assertEquals(206, open.getStatus());
        assertArrayEquals(Arrays.copyOfRange(raw, (int) len - 50, (int) len), open.getContentAsByteArray());

        MockHttpServletResponse suffix = new MockHttpServletResponse();
        service.serve(ME, u.id(), false, "bytes=-10", null, suffix);
        assertEquals(206, suffix.getStatus());
        assertArrayEquals(Arrays.copyOfRange(raw, (int) len - 10, (int) len), suffix.getContentAsByteArray());

        MockHttpServletResponse bad = new MockHttpServletResponse();
        service.serve(ME, u.id(), false, "bytes=" + (len + 10) + "-", null, bad);
        assertEquals(416, bad.getStatus());
        assertEquals("bytes */" + len, bad.getHeader("Content-Range"));

        MockHttpServletResponse garbage = new MockHttpServletResponse();
        service.serve(ME, u.id(), false, "bytes=abc", null, garbage);
        assertEquals(416, garbage.getStatus());
    }

    @Test
    void imageServedWithEtagAnd304ThumbToo() throws Exception {
        PostMediaService.Uploaded u = uploadImage(ME);
        ResponseEntity<Resource> r = service.serve(ME, u.id(), false, null, null, new MockHttpServletResponse());
        assertEquals(HttpStatus.OK, r.getStatusCode());
        assertEquals("image/jpeg", r.getHeaders().getContentType().toString());
        String etag = r.getHeaders().getETag();
        assertNotNull(etag);
        assertTrue(r.getHeaders().getCacheControl().contains("private"));
        assertTrue(r.getHeaders().getCacheControl().contains("max-age=86400"));
        ResponseEntity<Resource> nm = service.serve(ME, u.id(), false, null, etag, new MockHttpServletResponse());
        assertEquals(HttpStatus.NOT_MODIFIED, nm.getStatusCode());
        ResponseEntity<Resource> t = service.serve(ME, u.id(), true, null, null, new MockHttpServletResponse());
        assertEquals(HttpStatus.OK, t.getStatusCode());
        assertFalse(etag.equals(t.getHeaders().getETag()));
    }

    @Test
    void encryptedStoreServesDecryptedImage() throws Exception {
        init(true);
        PostMediaService.Uploaded u = uploadImage(ME);
        byte[] onDisk = Files.readAllBytes(dir.resolve("_private").resolve("post").resolve(db.get(u.id()).getStorageKey()));
        assertTrue(new String(onDisk, 0, 4, StandardCharsets.US_ASCII).startsWith("BUM1"));
        ResponseEntity<Resource> r = service.serve(ME, u.id(), false, null, null, new MockHttpServletResponse());
        assertNotNull(ImageIO.read(r.getBody().getInputStream()));
    }

    // ---------------------------------------------------------------- yetki

    @Test
    void unattachedVisibleOnlyToOwner() throws Exception {
        PostMediaService.Uploaded u = uploadImage(ME);
        assertTrue(service.accessible(ME, u.id()).isPresent());
        assertTrue(service.accessible(OTHER, u.id()).isEmpty());
        assertApi(HttpStatus.NOT_FOUND, "POST_MEDIA_NOT_FOUND",
                () -> service.serve(OTHER, u.id(), false, null, null, new MockHttpServletResponse()));
        assertTrue(service.accessible(ME, 99999L).isEmpty());
    }

    @Test
    void attachedVisibleToOthersUnlessPostDeletedHiddenOrBlocked() throws Exception {
        PostMediaService.Uploaded u = uploadImage(ME);
        service.attach(POST, ME, List.of(u.id()));
        assertTrue(service.accessible(OTHER, u.id()).isPresent());

        blockedForOther = Set.of(ME);
        assertTrue(service.accessible(OTHER, u.id()).isEmpty());
        assertTrue(service.accessible(ME, u.id()).isPresent());
        blockedForOther = Set.of();

        post(POST, ME, Instant.now(), null);
        assertTrue(service.accessible(OTHER, u.id()).isEmpty());
        assertTrue(service.accessible(ME, u.id()).isEmpty());

        post(POST, ME, null, Instant.now());
        assertTrue(service.accessible(OTHER, u.id()).isEmpty());

        post(POST, ME, null, null);
        assertTrue(service.accessible(OTHER, u.id()).isPresent());
        posts.remove(POST);
        assertTrue(service.accessible(OTHER, u.id()).isEmpty());
    }

    @Test
    void adminStreamsHiddenAndDeletedMedia() throws Exception {
        byte[] raw = Mp4Fixtures.mp4(5.0, 320, 240, 3000);
        PostMediaService.Uploaded u = service.upload(ME, videoFile(raw), null);
        service.attach(POST, ME, List.of(u.id()));
        service.hide(POST);
        post(POST, ME, Instant.now(), Instant.now());
        assertTrue(service.accessible(ME, u.id()).isEmpty());
        MockHttpServletResponse resp = new MockHttpServletResponse();
        assertNull(service.serveForAdmin(u.id(), false, "bytes=0-9", null, resp));
        assertEquals(206, resp.getStatus());
        assertArrayEquals(Arrays.copyOf(raw, 10), resp.getContentAsByteArray());
        assertApi(HttpStatus.NOT_FOUND, "POST_MEDIA_NOT_FOUND",
                () -> service.serveForAdmin(98765L, false, null, null, new MockHttpServletResponse()));
    }

    // ---------------------------------------------------------------- attach kurallari

    @Test
    void attachBindsInOrderAndViewsFollowPosition() throws Exception {
        PostMediaService.Uploaded a = uploadImage(ME);
        PostMediaService.Uploaded b = uploadVideo(ME, true);
        PostMediaService.Uploaded c = uploadVideo(ME, false);
        service.attach(POST, ME, List.of(c.id(), a.id(), b.id())); // karisik, istemci sirasi
        assertEquals(List.of(c.id(), a.id(), b.id()), service.mediaIdsOf(POST));
        Map<Long, List<MediaView>> v = service.viewsFor(List.of(POST, 777L), OTHER);
        assertEquals(1, v.size());
        List<MediaView> views = v.get(POST);
        assertEquals(List.of(c.id(), a.id(), b.id()), views.stream().map(MediaView::id).toList());
        assertEquals("VIDEO", views.get(0).kind());
        assertNull(views.get(0).thumbUrl()); // posterli degil
        assertEquals(5000, views.get(0).durationMs());
        assertEquals("IMAGE", views.get(1).kind());
        assertNull(views.get(1).durationMs());
        assertEquals("/api/posts/media/" + a.id() + "?thumb=true", views.get(1).thumbUrl());
        assertTrue(service.viewsFor(List.of(), OTHER).isEmpty());
    }

    @Test
    void attachRejectsInvalidInputs() throws Exception {
        PostMediaService.Uploaded mine = uploadImage(ME);
        PostMediaService.Uploaded theirs = uploadImage(OTHER);
        assertApi(HttpStatus.BAD_REQUEST, "POST_MEDIA_INVALID", () -> service.attach(POST, ME, List.of(theirs.id())));
        assertApi(HttpStatus.BAD_REQUEST, "POST_MEDIA_INVALID", () -> service.attach(POST, ME, List.of(mine.id(), 424242L)));
        assertApi(HttpStatus.BAD_REQUEST, "POST_MEDIA_INVALID",
                () -> service.attach(POST, ME, List.of(mine.id(), mine.id())));
        assertNull(db.get(mine.id()).getPostId());
        service.attach(POST, ME, List.of(mine.id()));
        assertApi(HttpStatus.BAD_REQUEST, "POST_MEDIA_INVALID", () -> service.attach(501L, ME, List.of(mine.id())));
        service.attach(POST, ME, List.of()); // bos: sorun yok
        service.attach(POST, ME, null);
    }

    @Test
    void attachAllowsTenButNotEleven() throws Exception {
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < 11; i++) {
            ids.add(uploadImage(ME).id());
        }
        assertApi(HttpStatus.BAD_REQUEST, "POST_MEDIA_INVALID", () -> service.attach(POST, ME, ids));
        service.attach(POST, ME, ids.subList(0, 10));
        assertEquals(10, service.mediaIdsOf(POST).size());
    }

    @Test
    void attachAllowsTenVideos() throws Exception {
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < 10; i++) {
            ids.add(uploadVideo(ME, false).id());
        }
        service.attach(POST, ME, ids);
        assertEquals(10, service.mediaIdsOf(POST).size());
    }

    // ---------------------------------------------------------------- gizleme / silme / supurucu

    @Test
    void hideAndUnhideToggleAccessAndViews() throws Exception {
        PostMediaService.Uploaded u = uploadImage(ME);
        service.attach(POST, ME, List.of(u.id()));
        service.hide(POST);
        assertTrue(service.accessible(OTHER, u.id()).isEmpty());
        assertTrue(service.accessible(ME, u.id()).isEmpty());
        assertTrue(service.viewsFor(List.of(POST), OTHER).isEmpty());
        service.hide(POST); // idempotent
        service.unhide(POST);
        assertTrue(service.accessible(OTHER, u.id()).isPresent());
        assertEquals(1, service.viewsFor(List.of(POST), OTHER).get(POST).size());
    }

    @Test
    void sweepUnattachedRemovesOldUnboundOnly() throws Exception {
        PostMediaService.Uploaded old = uploadImage(ME);
        PostMediaService.Uploaded fresh = uploadImage(ME);
        PostMediaService.Uploaded bound = uploadImage(ME);
        service.attach(POST, ME, List.of(bound.id()));
        db.get(old.id()).setCreatedAt(Instant.now().minus(Duration.ofHours(30)));
        db.get(bound.id()).setCreatedAt(Instant.now().minus(Duration.ofHours(30)));
        String oldKey = db.get(old.id()).getStorageKey();
        assertEquals(1, service.sweepUnattached(Duration.ofHours(24)));
        assertFalse(db.containsKey(old.id()));
        assertTrue(db.containsKey(fresh.id()));
        assertTrue(db.containsKey(bound.id()));
        assertFalse(Files.exists(dir.resolve("_private").resolve("post").resolve(oldKey)));
        assertEquals(4, fileCount()); // fresh + bound (ana + onizleme)
    }

    @Test
    void sweepUnattachedAlsoRemovesRowlessOldFiles() throws Exception {
        PostMediaService.Uploaded u = uploadImage(ME);
        String key = db.get(u.id()).getStorageKey();
        db.remove(u.id()); // satir yok, dosya yetim
        Path f = dir.resolve("_private").resolve("post").resolve(key);
        Files.setLastModifiedTime(f, java.nio.file.attribute.FileTime.from(Instant.now().minus(Duration.ofHours(48))));
        service.sweepUnattached(Duration.ofHours(24));
        assertFalse(Files.exists(f));
    }

    @Test
    void deletedPostMediaKeptThirtyDaysThenSwept() throws Exception {
        PostMediaService.Uploaded u = uploadImage(ME);
        service.attach(POST, ME, List.of(u.id()));
        String key = db.get(u.id()).getStorageKey();
        post(POST, ME, Instant.now().minus(Duration.ofDays(5)), null);
        service.onPostDeleted(new PostDeletedEvent(POST, List.of(u.id()))); // 30 gun saklama: dokunmaz
        assertTrue(db.containsKey(u.id()));
        assertEquals(0, service.sweepDeleted());
        post(POST, ME, Instant.now().minus(Duration.ofDays(31)), null);
        assertEquals(1, service.sweepDeleted());
        assertFalse(db.containsKey(u.id()));
        assertFalse(Files.exists(dir.resolve("_private").resolve("post").resolve(key)));
    }

    @Test
    void deleteEventWithZeroRetentionRemovesImmediately() throws Exception {
        service.setDeletedRetentionDays(0);
        PostMediaService.Uploaded u = uploadImage(ME);
        service.attach(POST, ME, List.of(u.id()));
        post(POST, ME, Instant.now(), null);
        service.onPostDeleted(new PostDeletedEvent(POST, List.of(u.id())));
        assertFalse(db.containsKey(u.id()));
        assertEquals(0, fileCount());
    }

    @Test
    void purgeUserRemovesAllOfTheirMedia() throws Exception {
        PostMediaService.Uploaded a = uploadImage(ME);
        PostMediaService.Uploaded b = uploadVideo(ME, true);
        PostMediaService.Uploaded other = uploadImage(OTHER);
        service.attach(POST, ME, List.of(a.id()));
        assertEquals(2, service.purgeUser(ME));
        assertFalse(db.containsKey(a.id()));
        assertFalse(db.containsKey(b.id()));
        assertTrue(db.containsKey(other.id()));
        assertEquals(2, fileCount()); // yalniz OTHER'in ana + onizleme
    }

    @Test
    void deleteUnattachedOnlyOwnUnboundUpload() throws Exception {
        PostMediaService.Uploaded a = uploadImage(ME);
        assertApi(HttpStatus.NOT_FOUND, "POST_MEDIA_NOT_FOUND", () -> service.deleteUnattached(OTHER, a.id()));
        service.attach(POST, ME, List.of(a.id()));
        assertApi(HttpStatus.CONFLICT, "POST_MEDIA_IN_USE", () -> service.deleteUnattached(ME, a.id()));
        PostMediaService.Uploaded b = uploadImage(ME);
        service.deleteUnattached(ME, b.id());
        assertFalse(db.containsKey(b.id()));
    }
}
