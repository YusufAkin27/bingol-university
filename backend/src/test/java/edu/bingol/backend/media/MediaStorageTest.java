package edu.bingol.backend.media;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.common.storage.LocalFileStorage;
import edu.bingol.backend.config.MediaProperties;
import edu.bingol.backend.config.StorageProperties;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.time.Duration;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.mock.web.MockMultipartFile;

class MediaStorageTest {

    @TempDir
    Path dir;

    MediaProperties props;
    LocalFileStorage storage;
    ImageProcessor processor;
    AtomicBoolean referenced = new AtomicBoolean(false);
    MediaService media;

    @BeforeEach
    void setUp() {
        props = ImageFixtures.props();
        processor = new ImageProcessor(props);
        storage = new LocalFileStorage(new StorageProperties(dir.toString()), processor, props);
        media = new MediaService(processor, storage, props, List.of(url -> referenced.get()));
    }

    private static MockMultipartFile file(byte[] data, String name, String type) {
        return new MockMultipartFile("file", name, type, data);
    }

    private static byte[] png(int w, int h) {
        return ImageFixtures.encode(ImageFixtures.gradient(w, h), "png");
    }

    private void age(String url) throws Exception {
        for (String u : new String[] {url, MediaService.thumbUrlOf(url)}) {
            Files.setLastModifiedTime(storage.root().resolve(u.substring("/files/".length())),
                    FileTime.fromMillis(System.currentTimeMillis() - 3L * 24 * 3600 * 1000));
        }
    }

    @Test
    void storesWithContentHashNameAndThumb() throws Exception {
        StoredImage a = media.storeImage(file(png(800, 600), "a.png", "image/png"), ImageKind.AVATAR);
        assertTrue(a.url().matches("/files/avatars/[0-9a-f]{40}\\.jpg"), a.url());
        assertEquals(MediaService.thumbUrlOf(a.url()), a.thumbUrl());
        assertEquals(512, a.width());
        assertTrue(Files.isRegularFile(storage.root().resolve(a.url().substring(7))));
        assertTrue(Files.isRegularFile(storage.root().resolve(a.thumbUrl().substring(7))));
        // ayni icerik = ayni dosya
        StoredImage b = media.storeImage(file(png(800, 600), "b.png", "image/png"), ImageKind.AVATAR);
        assertEquals(a.url(), b.url());
        StoredImage c = media.storeImage(file(png(801, 600), "c.png", "image/png"), ImageKind.AVATAR);
        assertNotEquals(a.url(), c.url());
        assertThrows(IllegalArgumentException.class,
                () -> media.storeImage(file(png(10, 10), "x.png", "image/png"), ImageKind.CHAT));
    }

    @Test
    void attackUploadsAreRejected() {
        byte[] svg = "<svg xmlns='http://www.w3.org/2000/svg'/>".getBytes();
        assertEquals("INVALID_FILE", code(file(svg, "a.svg", "image/svg+xml")));
        assertEquals("INVALID_FILE", code(file(svg, "a.png", "image/png"))); // sahte uzanti + tur, bayt SVG
        assertEquals("INVALID_FILE", code(file(png(10, 10), "a.gif", "image/png"))); // gercek PNG ama .gif adi
        assertEquals("INVALID_FILE", code(file(png(10, 10), "a.png", "text/html")));
        assertEquals("INVALID_FILE", code(file(new byte[0], "a.png", "image/png")));
        ApiException big = assertThrows(ApiException.class, () -> media.storeImage(
                file(new byte[3 * 1024 * 1024], "a.png", "image/png"), ImageKind.AVATAR));
        assertEquals("FILE_TOO_LARGE", big.code());
        assertEquals(413, big.status().value());
    }

    private String code(MockMultipartFile f) {
        return assertThrows(ApiException.class, () -> media.storeImage(f, ImageKind.AVATAR)).code();
    }

    @Test
    void uploadLimitIsConfigurable() {
        MediaProperties p = ImageFixtures.props(0, new MediaProperties.Limits(1000, 512, 150L << 10, 85));
        MediaService m = new MediaService(new ImageProcessor(p), storage, p, List.of());
        assertEquals("FILE_TOO_LARGE", assertThrows(ApiException.class, () -> m.storeImage(
                file(png(200, 200), "a.png", "image/png"), ImageKind.AVATAR)).code());
    }

    @Test
    void releaseDeletesOnlyUnreferencedAndNotFresh() throws Exception {
        StoredImage a = media.storeImage(file(png(100, 100), "a.png", "image/png"), ImageKind.AVATAR);
        Path main = storage.root().resolve(a.url().substring(7));
        media.release(a.url()); // taze: dokunma
        assertTrue(Files.exists(main));
        age(a.url());
        referenced.set(true);
        media.release(a.url()); // kullaniliyor
        assertTrue(Files.exists(main));
        referenced.set(false);
        media.release("/files/avatars/../../etc/passwd"); // gecersiz: sessiz
        media.release(null);
        media.release(a.url());
        assertFalse(Files.exists(main));
        assertFalse(Files.exists(storage.root().resolve(a.thumbUrl().substring(7))));
    }

    @Test
    void sweeperRemovesOnlyOldOrphans() throws Exception {
        StoredImage keep = media.storeImage(file(png(100, 100), "a.png", "image/png"), ImageKind.AVATAR);
        StoredImage orphan = media.storeImage(file(png(120, 100), "b.png", "image/png"), ImageKind.AVATAR);
        StoredImage fresh = media.storeImage(file(png(140, 100), "c.png", "image/png"), ImageKind.AVATAR);
        age(keep.url());
        age(orphan.url());
        MediaOrphanSweeper sweeper = new MediaOrphanSweeper(storage,
                new MediaService(processor, storage, props, List.of(u -> u.equals(keep.url()))), props);
        assertEquals(2, sweeper.sweepOnce()); // yetim + kucuk resmi
        assertTrue(Files.exists(storage.root().resolve(keep.url().substring(7))));
        assertFalse(Files.exists(storage.root().resolve(orphan.url().substring(7))));
        assertTrue(Files.exists(storage.root().resolve(fresh.url().substring(7))), "taze dosya silinmez");
    }

    @Test
    void concurrentIdenticalUploadsProduceOneIntactFile() throws Exception {
        byte[] data = png(300, 200);
        ExecutorService ex = Executors.newFixedThreadPool(12);
        List<Future<StoredImage>> fs = new java.util.ArrayList<>();
        for (int i = 0; i < 24; i++) {
            fs.add(ex.submit(() -> media.storeImage(file(data, "a.png", "image/png"), ImageKind.AVATAR)));
        }
        String url = fs.get(0).get().url();
        for (Future<StoredImage> f : fs) {
            assertEquals(url, f.get().url());
        }
        ex.shutdown();
        assertNotEquals(null, javax.imageio.ImageIO.read(storage.root().resolve(url.substring(7)).toFile()));
        try (var s = Files.list(storage.root().resolve("avatars"))) {
            assertEquals(2, s.count(), "yalniz ana + kucuk resim; gecici dosya kalmamali");
        }
    }

    @Test
    void legacyStorageSaveNowGoesThroughPipeline() {
        String url = storage.save("covers", file(png(2000, 500), "c.png", "image/png"),
                Set.of("image/png"), 3L << 20);
        assertTrue(url.startsWith("/files/covers/") && url.endsWith(".jpg"));
        assertThrows(ApiException.class, () -> storage.save("covers",
                file(new byte[] {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A}, "c.png", "image/png"),
                Set.of("image/png"), 3L << 20));
    }

    // --- ozel depo ---

    static final class XorCipher implements BlobCipher {
        @Override
        public byte[] encrypt(byte[] plain, String ctx) {
            return xor(plain);
        }

        @Override
        public byte[] decrypt(byte[] stored, String ctx) {
            return xor(stored);
        }

        private static byte[] xor(byte[] b) {
            byte[] o = b.clone();
            for (int i = 0; i < o.length; i++) {
                o[i] ^= 0x5A;
            }
            return o;
        }
    }

    @SuppressWarnings("unchecked")
    private PrivateMediaStore privateStore(BlobCipher cipher) {
        ObjectProvider<BlobCipher> prov = org.mockito.Mockito.mock(ObjectProvider.class);
        org.mockito.Mockito.when(prov.getIfAvailable(org.mockito.ArgumentMatchers.any())).thenAnswer(i ->
                cipher != null ? cipher : ((java.util.function.Supplier<BlobCipher>) i.getArgument(0)).get());
        return new PrivateMediaStore(new StorageProperties(dir.toString()), props, processor, prov);
    }

    @Test
    void privateStoreIsNotPublicAndRoundTrips() throws Exception {
        PrivateMediaStore store = privateStore(null);
        PrivateMedia m = store.store("chat", file(png(900, 900), "a.png", "image/png"), ImageKind.CHAT);
        assertTrue(m.key().matches("[0-9a-f\\-]{36}\\.jpg"));
        assertEquals(900, m.width());
        assertEquals(200, store.serve("chat", m.key()).getStatusCode().value());
        assertEquals("no-store", store.serve("chat", m.key()).getHeaders().getCacheControl());
        assertEquals(404, store.serve("chat", "00000000-0000-0000-0000-000000000000.jpg").getStatusCode().value());
        // yol gezintisi / gecersiz kova / anahtar
        assertNull(store.read("chat", "../x.jpg"));
        assertNull(store.read("../chat", m.key()));
        assertNull(store.read("chat", "a/b.jpg"));
        assertThrows(IllegalArgumentException.class, () ->
                store.store("Ba/d", file(png(10, 10), "a.png", "image/png"), ImageKind.CHAT));
        // /files/** altindan erisilemeyecek yerde
        assertFalse(Files.exists(storage.root().resolve("chat")));
        store.delete("chat", m.key());
        assertNull(store.read("chat", m.key()));
        assertNull(store.read("chat", m.thumbKey()));
    }

    @Test
    void privateStoreEncryptsViaBlobCipher() throws Exception {
        PrivateMediaStore store = privateStore(new XorCipher());
        PrivateMedia m = store.store("chat", png(64, 64), ImageKind.CHAT);
        byte[] onDisk = Files.readAllBytes(dir.resolve("_private").resolve("chat").resolve(m.key()));
        byte[] plain = store.read("chat", m.key());
        assertEquals((byte) 0xFF, plain[0]); // JPEG
        assertNotEquals(plain[0], onDisk[0]); // diskte sifreli
        assertArrayEquals(plain, new XorCipher().decrypt(onDisk, ""));
    }

    @Test
    void privateSweepRemovesUnreferencedOldOnly() throws Exception {
        PrivateMediaStore store = privateStore(null);
        PrivateMedia keep = store.store("chat", png(64, 64), ImageKind.CHAT);
        PrivateMedia drop = store.store("chat", png(65, 64), ImageKind.CHAT);
        assertEquals(0, store.sweep("chat", k -> false, Duration.ofHours(1))); // hepsi taze
        for (PrivateMedia m : List.of(keep, drop)) {
            Files.setLastModifiedTime(dir.resolve("_private/chat").resolve(m.key()),
                    FileTime.fromMillis(System.currentTimeMillis() - 7_200_000));
        }
        assertEquals(1, store.sweep("chat", k -> k.equals(keep.key()), Duration.ofHours(1)));
        assertNotEquals(null, store.read("chat", keep.key()));
        assertNull(store.read("chat", drop.key()));
    }

    @Test
    void signedUrlsVerifyAndExpire() {
        MediaUrlSigner s = new MediaUrlSigner(props, "jwt-secret-for-test-0123456789012345");
        String u = s.sign("chat", "ab-1.jpg", Duration.ofMinutes(5));
        long exp = Long.parseLong(u.replaceAll(".*exp=(\\d+)&.*", "$1"));
        String sig = u.substring(u.indexOf("sig=") + 4);
        assertTrue(s.verify("chat", "ab-1.jpg", exp, sig));
        assertFalse(s.verify("chat", "ab-2.jpg", exp, sig)); // baska dosya
        assertFalse(s.verify("other", "ab-1.jpg", exp, sig));
        assertFalse(s.verify("chat", "ab-1.jpg", exp + 1, sig)); // sure uzatma
        assertFalse(s.verify("chat", "ab-1.jpg", exp, sig.replace(sig.charAt(0), sig.charAt(0) == 'a' ? 'b' : 'a')));
        assertFalse(s.verify("chat", "ab-1.jpg", 1000, sig));
        assertFalse(s.verify("chat", "ab-1.jpg", exp, null));
        // 1 saatten uzun TTL kisaltilir
        String longU = s.sign("chat", "ab-1.jpg", Duration.ofDays(30));
        long e2 = Long.parseLong(longU.replaceAll(".*exp=(\\d+)&.*", "$1"));
        assertTrue(e2 - System.currentTimeMillis() / 1000 <= 3601);
    }
}
