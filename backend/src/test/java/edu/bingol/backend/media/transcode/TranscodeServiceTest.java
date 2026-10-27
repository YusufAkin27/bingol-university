package edu.bingol.backend.media.transcode;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.config.StorageProperties;
import edu.bingol.backend.crypto.CryptoService;
import edu.bingol.backend.crypto.CryptoTestSupport;
import edu.bingol.backend.media.ImageProcessor;
import edu.bingol.backend.media.NoopBlobCipher;
import edu.bingol.backend.media.PostVideoCipher;
import edu.bingol.backend.media.PrivateMediaStore;
import edu.bingol.backend.messaging.media.Mp4Fixtures;
import edu.bingol.backend.post.media.PostMedia;
import edu.bingol.backend.post.media.PostMediaService;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.data.domain.Pageable;

/**
 * Donusturme is akisi: sahte ffmpeg (surec calistirmaz) + gercek sifreli depo + bellek ici kayit deposu.
 * Durumlar: PENDING -> PROCESSING -> DONE / (PENDING | FAILED); orijinal hata durumunda bozulmaz.
 */
class TranscodeServiceTest {

    static final String B = PostMediaService.BUCKET;

    @TempDir
    Path dir;

    final Map<Long, PostMedia> db = new HashMap<>();
    final PostMediaTranscodeRepository repo = mock(PostMediaTranscodeRepository.class);
    PrivateMediaStore store;
    TranscodeProperties props;
    FakeFfmpeg ffmpeg;
    TranscodeService service;
    TranscodeWorker worker;
    byte[] original;

    /** ffmpeg/ffprobe taklidi: transcode = girdiyi "TRN" onekiyle kopyalar; poster = kucuk JPEG. */
    static class FakeFfmpeg implements ProcessRunner {
        volatile boolean failTranscode;
        volatile boolean probeNoVideo;
        volatile long probeMs = 3500;
        final List<List<String>> calls = new java.util.concurrent.CopyOnWriteArrayList<>();

        @Override
        public Output run(List<String> cmd, java.time.Duration timeout) throws IOException {
            calls.add(cmd);
            if (cmd.contains("-version")) {
                return new Output(0, "version", false);
            }
            if (cmd.get(0).equals("ffprobe")) {
                return probeNoVideo ? new Output(0, "duration=3.5\n", false)
                        : new Output(0, "width=640\nheight=360\nduration=" + (probeMs / 1000.0) + "\n", false);
            }
            Path out = Path.of(cmd.get(cmd.size() - 1));
            if (cmd.contains("image2")) {
                ByteArrayOutputStream o = new ByteArrayOutputStream();
                BufferedImage im = new BufferedImage(64, 36, BufferedImage.TYPE_INT_RGB);
                ImageIO.write(im, "jpg", o);
                Files.write(out, o.toByteArray());
                return new Output(0, "", false);
            }
            if (failTranscode) {
                return new Output(1, "Conversion failed!", false);
            }
            byte[] in = Files.readAllBytes(Path.of(cmd.get(cmd.indexOf("-i") + 1)));
            byte[] res = new byte[in.length + 3];
            System.arraycopy("TRN".getBytes(), 0, res, 0, 3);
            System.arraycopy(in, 0, res, 3, in.length);
            Files.write(out, res);
            return new Output(0, "", false);
        }
    }

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() throws Exception {
        MediaProperties mp = new MediaProperties(0, 4, 0, 0, 0, null, null, null, null, true, null, null, null, null);
        ObjectProvider<edu.bingol.backend.media.BlobCipher> cipher = mock(ObjectProvider.class);
        when(cipher.getIfAvailable(any())).thenReturn(new NoopBlobCipher());
        store = new PrivateMediaStore(new StorageProperties(dir.resolve("store").toString()), mp,
                new ImageProcessor(mp), cipher);
        store.setPostCipher(new PostVideoCipher(
                CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(9), ""), new CryptoService()));
        props = new TranscodeProperties(true, "ffmpeg", "ffprobe", 2, 1, 120, 720, 1500, 96, 90, 3, 5000, 30,
                dir.resolve("tmp").toString(), true, true, 5, "");
        ffmpeg = new FakeFfmpeg();
        VideoTranscoder tr = new VideoTranscoder(props, ffmpeg);
        service = new TranscodeService(repo, store, tr, props);
        worker = new TranscodeWorker(repo, service, tr, props);
        original = Mp4Fixtures.mp4(3.5, 640, 360, 5000);

        when(repo.findById(anyLong())).thenAnswer(i -> Optional.ofNullable(db.get(i.<Long>getArgument(0))));
        when(repo.pendingIds(any(Pageable.class))).thenAnswer(i -> db.values().stream()
                .filter(m -> "PENDING".equals(m.getTranscodeStatus())).map(PostMedia::getId).sorted().toList());
        when(repo.claim(anyLong(), any())).thenAnswer(i -> {
            PostMedia m = db.get(i.<Long>getArgument(0));
            if (m != null && "PENDING".equals(m.getTranscodeStatus())) {
                m.setTranscodeStatus("PROCESSING");
                return 1;
            }
            return 0;
        });
        when(repo.complete(anyLong(), anyString(), anyString(), anyLong(), any(), any(), any(), anyString(), any(),
                any())).thenAnswer(i -> {
            PostMedia m = db.get(i.<Long>getArgument(0));
            if (m == null || !"PROCESSING".equals(m.getTranscodeStatus())) {
                return 0;
            }
            m.setStorageKey(i.getArgument(1));
            m.setWrappedDek(i.getArgument(2));
            m.setEncrypted(true);
            m.setBytes(i.getArgument(3));
            m.setDurationMs(i.getArgument(4));
            m.setWidth(i.getArgument(5));
            m.setHeight(i.getArgument(6));
            m.setSha256(i.getArgument(7));
            m.setThumbKey(i.getArgument(8));
            m.setTranscodeStatus("DONE");
            return 1;
        });
        when(repo.fail(anyLong(), anyInt(), any())).thenAnswer(i -> {
            PostMedia m = db.get(i.<Long>getArgument(0));
            if (m == null || !"PROCESSING".equals(m.getTranscodeStatus())) {
                return 0;
            }
            m.setTranscodeAttempts((short) (m.getTranscodeAttempts() + 1));
            m.setTranscodeStatus(m.getTranscodeAttempts() >= i.<Integer>getArgument(1) ? "FAILED" : "PENDING");
            return 1;
        });
        when(repo.reseal(anyLong(), anyString(), anyString(), anyString(), anyString(), any())).thenAnswer(i -> {
            PostMedia m = db.get(i.<Long>getArgument(0));
            if (m == null || !m.isEncrypted() || !m.getStorageKey().equals(i.getArgument(1))
                    || !m.getWrappedDek().equals(i.getArgument(2))) {
                return 0;
            }
            m.setStorageKey(i.getArgument(3));
            m.setWrappedDek(i.getArgument(4));
            m.setThumbKey(i.getArgument(5));
            return 1;
        });
        when(repo.plainVideoIds(any(Pageable.class))).thenAnswer(i -> db.values().stream()
                .filter(m -> m.isVideo() && !m.isEncrypted()
                        && (m.getTranscodeStatus() == null || m.getTranscodeStatus().equals("DONE")))
                .map(PostMedia::getId).toList());
        when(repo.sealExisting(anyLong(), anyString(), anyString(), anyString(), any())).thenAnswer(i -> {
            PostMedia m = db.get(i.<Long>getArgument(0));
            if (m == null || m.isEncrypted() || !m.getStorageKey().equals(i.getArgument(1))) {
                return 0;
            }
            m.setStorageKey(i.getArgument(2));
            m.setWrappedDek(i.getArgument(3));
            m.setEncrypted(true);
            m.setThumbKey(i.getArgument(4));
            return 1;
        });
    }

    /** Sifreli yazilmis bir gonderi videosu satiri (yuklemenin urettigi hal), istege bagli posterli. */
    PostMedia sealedUpload(long id, boolean poster) {
        String[] st = store.storeVideoSealed(B, original, poster ? jpeg() : null, 720, null,
                edu.bingol.backend.media.ImageKind.FEED);
        PostMedia m = base(id, st[0], st[1]);
        m.setWrappedDek(st[4]);
        m.setEncrypted(true);
        m.setTranscodeStatus("PENDING");
        db.put(id, m);
        return m;
    }

    PostMedia base(long id, String key, String thumb) {
        PostMedia m = new PostMedia();
        m.setId(id);
        m.setOwnerId(1L);
        m.setKind(PostMedia.VIDEO);
        m.setStorageKey(key);
        m.setThumbKey(thumb);
        m.setContentType("video/mp4");
        m.setBytes(original.length);
        m.setDurationMs(3500);
        return m;
    }

    static byte[] jpeg() {
        try {
            ByteArrayOutputStream o = new ByteArrayOutputStream();
            ImageIO.write(new BufferedImage(320, 180, BufferedImage.TYPE_INT_RGB), "jpg", o);
            return o.toByteArray();
        } catch (IOException e) {
            throw new IllegalStateException(e);
        }
    }

    byte[] playable(PostMedia m) throws IOException {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        if (m.isEncrypted()) {
            store.streamSealedVideo(B, m.getStorageKey(), m.getWrappedDek(), 0, Long.MAX_VALUE - 1, o);
        } else {
            store.streamVideo(B, m.getStorageKey(), 0L, 0, Long.MAX_VALUE - 1, o);
        }
        return o.toByteArray();
    }

    Path file(String key) {
        return dir.resolve("store").resolve("_private").resolve(B).resolve(key);
    }

    @Test
    void successReplacesOriginalWithEncryptedTranscodeAndKeepsPoster() throws Exception {
        PostMedia m = sealedUpload(1, true);
        String oldKey = m.getStorageKey();
        String oldPoster = m.getThumbKey();
        assertNotNull(oldPoster);
        assertEquals(1, repo.claim(1L, java.time.Instant.now()));

        assertTrue(service.process(1));

        assertEquals("DONE", m.getTranscodeStatus());
        assertNotEquals(oldKey, m.getStorageKey(), "yeni anahtar: ETag/onbellek tazelenir");
        assertTrue(m.isEncrypted());
        assertNotNull(m.getWrappedDek());
        assertEquals(original.length + 3, m.getBytes());
        assertEquals(640, m.getWidth());
        assertEquals(360, m.getHeight());
        assertEquals(3500, m.getDurationMs());
        assertNotNull(m.getSha256());
        assertFalse(Files.exists(file(oldKey)), "eski orijinal silindi");
        assertFalse(Files.exists(file(oldPoster)), "eski poster silindi");
        assertTrue(Files.exists(file(m.getThumbKey())), "poster yeni kimlikle korunur");
        assertTrue(m.getThumbKey().startsWith(m.getStorageKey().replace(".mp4", "")), "poster video kimligini tasir");

        byte[] served = playable(m);
        assertEquals(m.getBytes(), served.length);
        assertArrayEquals("TRN".getBytes(), java.util.Arrays.copyOf(served, 3));
        // diskte duz degil
        assertFalse(new String(Files.readAllBytes(file(m.getStorageKey())),
                java.nio.charset.StandardCharsets.ISO_8859_1).contains("ftyp"));
        // post silinince video+poster birlikte kaldirilir (sizinti yok)
        store.delete(B, m.getStorageKey());
        assertFalse(Files.exists(file(m.getThumbKey())));
    }

    @Test
    void missingPosterIsGeneratedFromFirstFrame() throws Exception {
        PostMedia m = sealedUpload(2, false);
        assertNull(m.getThumbKey());
        repo.claim(2L, java.time.Instant.now());
        assertTrue(service.process(2));
        assertNotNull(m.getThumbKey(), "poster gonderilmediyse ffmpeg karesinden uretilir");
        assertTrue(m.getThumbKey().endsWith(".jpg") || m.getThumbKey().endsWith(".png"));
        assertNotNull(store.read(B, m.getThumbKey()));
        assertTrue(ffmpeg.calls.stream().anyMatch(c -> c.contains("image2")));
    }

    @Test
    void ffmpegFailureKeepsOriginalAndRetriesThenFails() throws Exception {
        ffmpeg.failTranscode = true;
        PostMedia m = sealedUpload(3, true);
        String key = m.getStorageKey();
        byte[] before = playable(m);

        repo.claim(3L, java.time.Instant.now());
        assertFalse(service.process(3));
        assertEquals("PENDING", m.getTranscodeStatus(), "ilk hata: yeniden denenecek");
        assertEquals(key, m.getStorageKey());
        assertArrayEquals(before, playable(m), "orijinal bozulmadi, sunulabilir");

        repo.claim(3L, java.time.Instant.now());
        assertFalse(service.process(3));
        repo.claim(3L, java.time.Instant.now());
        assertFalse(service.process(3));
        assertEquals("FAILED", m.getTranscodeStatus(), "3 hata: FAILED, orijinal kullanilir");
        assertEquals(3, m.getTranscodeAttempts());
        assertArrayEquals(before, playable(m));
        assertTrue(Files.exists(file(m.getThumbKey())), "poster da yerinde");
        // gecici dizin temizlendi
        try (var s = Files.list(dir.resolve("tmp"))) {
            assertEquals(0, s.count());
        }
    }

    @Test
    void invalidProbeOrTooLongIsAFailureNotACrash() throws Exception {
        ffmpeg.probeNoVideo = true;
        PostMedia m = sealedUpload(4, false);
        repo.claim(4L, java.time.Instant.now());
        assertFalse(service.process(4));
        assertEquals("PENDING", m.getTranscodeStatus());

        ffmpeg.probeNoVideo = false;
        ffmpeg.probeMs = 600_000; // 10 dk > sinir
        repo.claim(4L, java.time.Instant.now());
        assertFalse(service.process(4));
    }

    @Test
    void rowDeletedMeanwhileLeavesNoOrphanFiles() throws Exception {
        PostMedia m = sealedUpload(5, true);
        repo.claim(5L, java.time.Instant.now());
        // is bitmeden satir "silindi": complete() 0 doner
        when(repo.complete(anyLong(), anyString(), anyString(), anyLong(), any(), any(), any(), anyString(), any(),
                any())).thenReturn(0);
        assertFalse(service.process(5));
        try (var s = Files.list(file("x").getParent())) {
            long videos = s.filter(p -> p.getFileName().toString().endsWith(".mp4")).count();
            assertEquals(1, videos, "yalniz orijinal kaldi (yeni dosya silindi)");
        }
    }

    @Test
    void workerClaimsAtomicallyAndSkipsLostRaces() {
        sealedUpload(6, false);
        sealedUpload(7, false);
        // 6'yi baska bir ornek aldi; ama bu ornegin listesinde hala gorunuyor (yaris): claim 0 doner
        db.get(6L).setTranscodeStatus("PROCESSING");
        when(repo.pendingIds(any(Pageable.class))).thenReturn(List.of(6L, 7L));
        int n = worker.drainOnce();
        assertEquals(1, n);
        assertEquals("DONE", db.get(7L).getTranscodeStatus());
        assertEquals("PROCESSING", db.get(6L).getTranscodeStatus(), "baskasinin isine dokunulmaz");
        assertEquals(1, worker.doneCount());
    }

    @Test
    void workerRunsAtMostConfiguredConcurrency() {
        for (long i = 10; i < 16; i++) {
            sealedUpload(i, false);
        }
        // pendingIds sayfa boyutunu gormezden gelir: worker yine de en fazla `workers` is sahiplenmeli
        when(repo.pendingIds(any(Pageable.class))).thenAnswer(i -> {
            Pageable p = i.getArgument(0);
            return db.values().stream().filter(m -> "PENDING".equals(m.getTranscodeStatus())).map(PostMedia::getId)
                    .sorted().limit(p.getPageSize()).toList();
        });
        assertEquals(2, worker.drainOnce());
        assertEquals(2, db.values().stream().filter(m -> "DONE".equals(m.getTranscodeStatus())).count());
        assertEquals(4, db.values().stream().filter(m -> "PENDING".equals(m.getTranscodeStatus())).count());
    }

    @Test
    void workerDoesNothingWhenFfmpegMissing() {
        VideoTranscoder none = new VideoTranscoder(props, (c, t) -> {
            throw new IOException("yok");
        });
        TranscodeWorker w = new TranscodeWorker(repo, service, none, new TranscodeProperties(true, "ffmpeg",
                "ffprobe", 2, 1, 120, 720, 1500, 96, 90, 3, 5000, 30, "", true, false, 5, ""));
        sealedUpload(20, false);
        assertEquals(0, w.drainOnce());
        assertEquals("PENDING", db.get(20L).getTranscodeStatus(), "ffmpeg yoksa kuyruk bekler, orijinal sunulur");
        verify(repo, never()).claim(anyLong(), any());
    }

    @Test
    void legacyPlainVideoIsEncryptedInPlace() throws Exception {
        // eski kayit: duz yazilmis video + sifreli poster
        String[] st = store.storeVideoPlain(B, original, jpeg(), 720, null, edu.bingol.backend.media.ImageKind.FEED);
        PostMedia m = base(30, st[0], st[1]);
        db.put(30L, m);
        String oldKey = m.getStorageKey();
        assertTrue(new String(Files.readAllBytes(file(oldKey)), java.nio.charset.StandardCharsets.ISO_8859_1)
                .contains("ftyp"), "baslangicta duz");

        assertTrue(service.encryptExisting(30));

        assertTrue(m.isEncrypted());
        assertNotEquals(oldKey, m.getStorageKey());
        assertFalse(Files.exists(file(oldKey)));
        assertArrayEquals(original, playable(m), "icerik ayni, diskte sifreli");
        assertFalse(new String(Files.readAllBytes(file(m.getStorageKey())),
                java.nio.charset.StandardCharsets.ISO_8859_1).contains("ftyp"));
        assertNotNull(store.read(B, m.getThumbKey()), "poster tasindi");
        assertFalse(service.encryptExisting(30), "ikinci kez: zaten sifreli");
    }

    @Test
    void resealRewritesVideoUnderNewActiveMasterKey() throws Exception {
        PostMedia m = sealedUpload(40, true);
        m.setTranscodeStatus("DONE");
        String oldKey = m.getStorageKey();
        String oldDek = m.getWrappedDek();
        assertTrue(oldDek.startsWith("k1:"));
        // anahtar rotasyonu: k2 aktif, k1 listede kaliyor
        store.setPostCipher(new PostVideoCipher(CryptoTestSupport.provider(
                "k1:" + CryptoTestSupport.b64(9) + ",k2:" + CryptoTestSupport.b64(8), "k2"), new CryptoService()));

        assertTrue(service.reseal(40));

        assertTrue(m.getWrappedDek().startsWith("k2:"), "yeni DEK aktif anahtarla sarili");
        assertNotEquals(oldKey, m.getStorageKey());
        assertFalse(Files.exists(file(oldKey)));
        assertArrayEquals(original, playable(m), "icerik ayni");
        assertNotNull(store.read(B, m.getThumbKey()));
    }

    @Test
    void workerEncryptsLegacyWhenEnabled() {
        String[] st = store.storeVideoPlain(B, original, null, 720, null, edu.bingol.backend.media.ImageKind.FEED);
        db.put(31L, base(31, st[0], null));
        worker.drainOnce();
        assertTrue(db.get(31L).isEncrypted());
    }
}
