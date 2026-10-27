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
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.RateLimiter;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.config.StorageProperties;
import edu.bingol.backend.crypto.CryptoService;
import edu.bingol.backend.crypto.CryptoTestSupport;
import edu.bingol.backend.media.BlobCipher;
import edu.bingol.backend.media.ImageProcessor;
import edu.bingol.backend.media.MediaUrlSigner;
import edu.bingol.backend.media.NoopBlobCipher;
import edu.bingol.backend.media.PostVideoCipher;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.media.transcode.MediaCdnLinks;
import edu.bingol.backend.media.transcode.MediaCdnProperties;
import edu.bingol.backend.media.transcode.PostMediaCdnController;
import edu.bingol.backend.media.transcode.ProcessRunner;
import edu.bingol.backend.media.transcode.TranscodeProperties;
import edu.bingol.backend.media.transcode.VideoTranscoder;
import edu.bingol.backend.messaging.media.Mp4Fixtures;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.moderation.ContentBlocklist;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.mock.web.MockMultipartFile;

/**
 * Gonderi videosu: yukleme DEK ile sifreli yazar, ffmpeg varsa PENDING isaretler, Range okuma sifreyi cozer,
 * eski (duz) kayit geriye uyumlu okunur; CDN imzali URL ve origin ucu.
 */
class PostMediaSealedVideoTest {

    @TempDir
    Path dir;

    final Map<Long, PostMedia> db = new HashMap<>();
    final AtomicLong seq = new AtomicLong(100);
    final PostMediaRepository repo = mock(PostMediaRepository.class);
    PrivateMediaStore store;
    PostMediaService service;
    byte[] video;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        MediaProperties props = new MediaProperties(0, 4, 0, 0, 0, null, null, null, null, true, null, null, null, null);
        ObjectProvider<BlobCipher> cipher = mock(ObjectProvider.class);
        when(cipher.getIfAvailable(any())).thenReturn(new NoopBlobCipher());
        store = new PrivateMediaStore(new StorageProperties(dir.toString()), props, new ImageProcessor(props), cipher);
        service = new PostMediaService(repo, store, props, mock(ContentBlocklist.class), mock(BlockService.class),
                mock(RateLimiter.class));
        video = Mp4Fixtures.mp4(3.0, 320, 240, 200_000);
        when(repo.save(any(PostMedia.class))).thenAnswer(inv -> {
            PostMedia m = inv.getArgument(0);
            if (m.getId() == null) {
                m.setId(seq.incrementAndGet());
            }
            db.put(m.getId(), m);
            return m;
        });
        when(repo.findById(anyLong())).thenAnswer(inv -> Optional.ofNullable(db.get(inv.<Long>getArgument(0))));
    }

    void enableEncryption() {
        store.setPostCipher(new PostVideoCipher(
                CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(5), ""), new CryptoService()));
    }

    void enableFfmpeg() {
        TranscodeProperties tp = new TranscodeProperties(true, "ffmpeg", "ffprobe", 2, 1, 120, 720, 1500, 96, 90, 3,
                5000, 30, "", true, false, 5, "");
        service.setTranscoder(new VideoTranscoder(tp, (c, t) -> new ProcessRunner.Output(0, "ok", false)));
    }

    PostMediaService.Uploaded upload() {
        return service.upload(1L, new MockMultipartFile("file", "v.mp4", "video/mp4", video), null);
    }

    MockHttpServletResponse get(long id, String range) {
        MockHttpServletResponse resp = new MockHttpServletResponse();
        service.serveForAdmin(id, false, range, null, resp);
        return resp;
    }

    @Test
    void uploadWritesEncryptedAndQueuesTranscodeWhenFfmpegAvailable() throws Exception {
        enableEncryption();
        enableFfmpeg();
        var up = upload();
        PostMedia m = db.get(up.id());
        assertTrue(m.isEncrypted());
        assertNotNull(m.getWrappedDek());
        assertEquals("PENDING", m.getTranscodeStatus());
        byte[] disk = Files.readAllBytes(dir.resolve("_private").resolve("post").resolve(m.getStorageKey()));
        assertFalse(new String(disk, java.nio.charset.StandardCharsets.ISO_8859_1).contains("ftyp"),
                "diskte video baytlari duz degil");
        assertEquals(video.length, m.getBytes());

        MockHttpServletResponse all = get(m.getId(), null);
        assertEquals(200, all.getStatus());
        assertArrayEquals(video, all.getContentAsByteArray());

        MockHttpServletResponse part = get(m.getId(), "bytes=1000-70000");
        assertEquals(206, part.getStatus());
        assertArrayEquals(Arrays.copyOfRange(video, 1000, 70001), part.getContentAsByteArray());
        assertEquals("bytes 1000-70000/" + video.length, part.getHeader("Content-Range"));
        assertEquals(416, get(m.getId(), "bytes=" + (video.length + 5) + "-").getStatus());
    }

    @Test
    void withoutFfmpegStatusStaysNullAndOriginalIsServed() throws Exception {
        enableEncryption();
        service.setTranscoder(new VideoTranscoder(new TranscodeProperties(true, "ffmpeg", "ffprobe", 2, 1, 120, 720,
                1500, 96, 90, 3, 5000, 30, "", true, false, 5, ""), (c, t) -> {
            throw new java.io.IOException("ffmpeg yok");
        }));
        PostMedia m = db.get(upload().id());
        assertNull(m.getTranscodeStatus(), "ffmpeg yoksa mevcut davranis: kuyruga alinmaz");
        assertTrue(m.isEncrypted());
        assertArrayEquals(video, get(m.getId(), null).getContentAsByteArray());
    }

    @Test
    void withoutMasterKeyFallsBackToLegacyPlainStorage() throws Exception {
        var up = upload(); // postCipher yok (gelistirme)
        PostMedia m = db.get(up.id());
        assertFalse(m.isEncrypted());
        assertNull(m.getWrappedDek());
        assertNull(m.getTranscodeStatus());
        assertArrayEquals(video, get(m.getId(), null).getContentAsByteArray());
    }

    @Test
    void legacyPlainRowStillReadableAfterEncryptionIsEnabled() throws Exception {
        var up = upload(); // duz kayit
        enableEncryption(); // sonradan anahtar geldi
        assertArrayEquals(Arrays.copyOfRange(video, 10, 5000), get(up.id(), "bytes=10-4999").getContentAsByteArray());
    }

    @Test
    void cdnLinksAreSignedShortLivedAndOnlyWhenConfigured() {
        MediaProperties mp = new MediaProperties(0, 4, 0, 0, 0, null, null, null, null, true, null, null, null, null);
        MediaUrlSigner signer = new MediaUrlSigner(mp, "jwt-secret-for-tests-0123456789abcdef");
        assertNull(new MediaCdnLinks(new MediaCdnProperties("", false, 300), signer).url(5, false), "kapali");
        assertNull(new MediaCdnLinks(new MediaCdnProperties("http://cdn.example", true, 300), signer).url(5, false),
                "https olmayan taban kabul edilmez");

        MediaCdnLinks links = new MediaCdnLinks(new MediaCdnProperties("https://cdn.example.edu.tr/", true, 300), signer);
        assertTrue(links.redirectEnabled());
        String url = links.url(5, false);
        assertTrue(url.startsWith("https://cdn.example.edu.tr/files/cdn/post/5?t=0&exp="), url);
        long exp = Long.parseLong(url.replaceAll(".*exp=(\\d+).*", "$1"));
        String sig = url.replaceAll(".*sig=([0-9a-f]+).*", "$1");
        assertTrue(links.verify(5, false, exp, sig));
        assertFalse(links.verify(6, false, exp, sig), "baska medya");
        assertFalse(links.verify(5, true, exp, sig), "poster icin gecersiz");
        assertFalse(links.verify(5, false, exp + 1, sig), "sure degistirilemez");
        assertFalse(links.verify(5, false, exp, "00" + sig.substring(2)));
        assertTrue(links.maxAgeSeconds(exp) <= 300);
    }

    @Test
    void cdnOriginEndpointRejectsBadSignatureAndServesPublicShortLived() throws Exception {
        enableEncryption();
        MediaProperties mp = new MediaProperties(0, 4, 0, 0, 0, null, null, null, null, true, null, null, null, null);
        MediaCdnLinks links = new MediaCdnLinks(new MediaCdnProperties("https://cdn.example.edu.tr", true, 120),
                new MediaUrlSigner(mp, "jwt-secret-for-tests-0123456789abcdef"));
        service.setCdn(links);
        PostMediaCdnController ctl = new PostMediaCdnController(links, service);
        PostMedia m = db.get(upload().id());
        MockHttpServletResponse resp = new MockHttpServletResponse();

        String url = links.url(m.getId(), false);
        long exp = Long.parseLong(url.replaceAll(".*exp=(\\d+).*", "$1"));
        String sig = url.replaceAll(".*sig=([0-9a-f]+).*", "$1");

        assertEquals(HttpStatus.NOT_FOUND, ctl.get(m.getId(), 0, exp, "x" + sig, null, null, resp).getStatusCode());

        // baglanmamis medya (postId yok) imzali olsa bile CDN'e verilmez
        assertThrows(ApiException.class, () -> ctl.get(m.getId(), 0, exp, sig, null, null, resp));

        // gonderiye bagli, gonderi acik
        m.setPostId(500L);
        PostMediaRepository.PostState open = mock(PostMediaRepository.PostState.class);
        when(open.getAuthorId()).thenReturn(1L);
        when(repo.postState(500L)).thenReturn(Optional.of(open));
        MockHttpServletResponse ok = new MockHttpServletResponse();
        ctl.get(m.getId(), 0, exp, sig, "bytes=0-99", null, ok);
        assertEquals(206, ok.getStatus());
        String cc = ok.getHeader("Cache-Control");
        assertTrue(cc.contains("public") && cc.contains("max-age="), cc);
        assertTrue(Long.parseLong(cc.replaceAll(".*max-age=(\\d+).*", "$1")) <= 120);
        assertArrayEquals(Arrays.copyOf(video, 100), ok.getContentAsByteArray());

        // gizlenince imza gecerli olsa da 404
        m.setHiddenAt(java.time.Instant.now());
        assertThrows(ApiException.class, () -> ctl.get(m.getId(), 0, exp, sig, null, null, new MockHttpServletResponse()));
    }

    @Test
    void userRequestRedirectsToSignedCdnOnlyWhenRedirectModeOn() throws Exception {
        enableEncryption();
        MediaProperties mp = new MediaProperties(0, 4, 0, 0, 0, null, null, null, null, true, null, null, null, null);
        PostMedia m = db.get(upload().id());
        m.setPostId(500L);
        PostMediaRepository.PostState open = mock(PostMediaRepository.PostState.class);
        when(open.getAuthorId()).thenReturn(7L);
        when(repo.postState(500L)).thenReturn(Optional.of(open));
        var blocks = mock(BlockService.class);
        when(blocks.hiddenFrom(anyLong())).thenReturn(java.util.Set.of());
        service = new PostMediaService(repo, store, mp, mock(ContentBlocklist.class), blocks, mock(RateLimiter.class));

        // redirect kapali: oturumlu sunum (200/206, private)
        service.setCdn(new MediaCdnLinks(new MediaCdnProperties("https://cdn.example.edu.tr", false, 300),
                new MediaUrlSigner(mp, "jwt-secret-for-tests-0123456789abcdef")));
        MockHttpServletResponse direct = new MockHttpServletResponse();
        service.serve(2L, m.getId(), false, null, null, direct);
        assertEquals(200, direct.getStatus());
        assertTrue(direct.getHeader("Cache-Control").contains("private"));

        // redirect acik: 302 + imzali URL, no-store
        service.setCdn(new MediaCdnLinks(new MediaCdnProperties("https://cdn.example.edu.tr", true, 300),
                new MediaUrlSigner(mp, "jwt-secret-for-tests-0123456789abcdef")));
        var r = service.serve(2L, m.getId(), false, null, null, new MockHttpServletResponse());
        assertEquals(HttpStatus.FOUND, r.getStatusCode());
        assertTrue(r.getHeaders().getFirst("Location").startsWith("https://cdn.example.edu.tr/files/cdn/post/"));
        assertTrue(r.getHeaders().getCacheControl().contains("no-store"));
    }
}
