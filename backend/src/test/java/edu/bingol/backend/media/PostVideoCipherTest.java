package edu.bingol.backend.media;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.crypto.CryptoException;
import edu.bingol.backend.crypto.CryptoService;
import edu.bingol.backend.crypto.CryptoTestSupport;
import edu.bingol.backend.crypto.KeyProvider;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Random;
import javax.crypto.SecretKey;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/** Gonderi videosu sifreleme: yazma/okuma, Range, kurcalama, baglam ve ana anahtar davranisi. */
class PostVideoCipherTest {

    static final int CHUNK = 1024; // kucuk parca: sinir durumlari ucuza test edilir

    @TempDir
    Path dir;

    KeyProvider keys;
    PostVideoCipher cipher;

    @BeforeEach
    void setUp() {
        keys = CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(3) + ",k2:" + CryptoTestSupport.b64(4), "k1");
        cipher = new PostVideoCipher(keys, new CryptoService(), CHUNK);
    }

    static byte[] data(int n) {
        byte[] b = new byte[n];
        new Random(42).nextBytes(b);
        return b;
    }

    Path seal(byte[] plain, SecretKey dek, String ctx) throws IOException {
        Path f = dir.resolve("v-" + plain.length + ".bin");
        try (var o = Files.newOutputStream(f)) {
            cipher.encrypt(dek, ctx, new ByteArrayInputStream(plain), o);
        }
        return f;
    }

    byte[] range(Path f, SecretKey dek, String ctx, long s, long e) throws IOException {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        cipher.decryptRange(f, dek, ctx, s, e, o);
        return o.toByteArray();
    }

    @Test
    void roundTripForBoundarySizes() throws Exception {
        for (int n : new int[] {0, 1, CHUNK - 1, CHUNK, CHUNK + 1, 3 * CHUNK, 3 * CHUNK + 17}) {
            var dek = cipher.newDek("post/a.mp4");
            byte[] plain = data(n);
            Path f = seal(plain, dek.key(), "post/a.mp4");
            assertEquals(cipher.sealedSize(n), Files.size(f), "boyut n=" + n);
            assertArrayEquals(plain, range(f, dek.key(), "post/a.mp4", 0, Long.MAX_VALUE - 1), "n=" + n);
        }
    }

    @Test
    void ciphertextIsNotPlaintext() throws Exception {
        var dek = cipher.newDek("post/a.mp4");
        byte[] plain = "ftypisom-VIDEO-ICERIGI-VIDEO-ICERIGI".repeat(200).getBytes();
        byte[] disk = Files.readAllBytes(seal(plain, dek.key(), "post/a.mp4"));
        assertTrue(new String(disk, java.nio.charset.StandardCharsets.ISO_8859_1).indexOf("VIDEO-ICERIGI") < 0);
        assertEquals('B', disk[0]);
        assertEquals('U', disk[1]);
        assertEquals('P', disk[2]);
        assertEquals('1', disk[3]);
    }

    @Test
    void rangeReadsOnlyRequestedBytesAcrossChunks() throws Exception {
        var dek = cipher.newDek("post/r.mp4");
        byte[] plain = data(10 * CHUNK + 123);
        Path f = seal(plain, dek.key(), "post/r.mp4");
        long[][] cases = {{0, 0}, {5, 5}, {0, CHUNK - 1}, {CHUNK - 1, CHUNK}, {CHUNK, 3 * CHUNK + 7},
                {4 * CHUNK + 1, plain.length - 1}, {plain.length - 1, plain.length - 1}, {2, Long.MAX_VALUE - 1}};
        for (long[] c : cases) {
            long end = Math.min(c[1], plain.length - 1);
            assertArrayEquals(Arrays.copyOfRange(plain, (int) c[0], (int) end + 1),
                    range(f, dek.key(), "post/r.mp4", c[0], c[1]), "aralik " + c[0] + "-" + c[1]);
        }
    }

    @Test
    void tamperedChunkTruncationAndWrongContextAreRejected() throws Exception {
        var dek = cipher.newDek("post/t.mp4");
        byte[] plain = data(4 * CHUNK);
        Path f = seal(plain, dek.key(), "post/t.mp4");

        byte[] disk = Files.readAllBytes(f);
        disk[PostVideoCipher.HEADER + 10] ^= 0x01;
        Path bad = dir.resolve("bad.bin");
        Files.write(bad, disk);
        assertThrows(CryptoException.class, () -> range(bad, dek.key(), "post/t.mp4", 0, 100));

        // son parcanin kesilmesi (ya da son parcayi atma): son-parca bayragi AAD'de oldugundan yakalanir
        byte[] whole = Files.readAllBytes(f);
        Path cut = dir.resolve("cut.bin");
        Files.write(cut, Arrays.copyOf(whole, whole.length - (CHUNK + 16)));
        assertThrows(CryptoException.class, () -> range(cut, dek.key(), "post/t.mp4", 0, Long.MAX_VALUE - 1));

        // baska dosya adi/baglami ile cozme
        assertThrows(CryptoException.class, () -> range(f, dek.key(), "post/baska.mp4", 0, 10));
        // baska DEK
        var other = cipher.newDek("post/t.mp4");
        assertThrows(CryptoException.class, () -> range(f, other.key(), "post/t.mp4", 0, 10));
    }

    @Test
    void wrappedDekRoundTripsAndIsBoundToContext() {
        var dek = cipher.newDek("post/x.mp4");
        assertTrue(dek.wrapped().startsWith("k1:"), "aktif ana anahtar kimligi");
        assertArrayEquals(dek.key().getEncoded(), cipher.unwrap(dek.wrapped(), "post/x.mp4").getEncoded());
        assertThrows(CryptoException.class, () -> cipher.unwrap(dek.wrapped(), "post/y.mp4"));
        assertThrows(CryptoException.class, () -> cipher.unwrap("zzz", "post/x.mp4"));
        assertThrows(CryptoException.class, () -> cipher.unwrap(null, "post/x.mp4"));
    }

    @Test
    void everyFileGetsItsOwnDek() {
        assertNotEquals(cipher.newDek("post/a.mp4").wrapped(), cipher.newDek("post/a.mp4").wrapped());
    }

    @Test
    void rotationOldKeyStillUnwraps() {
        var dek = cipher.newDek("post/z.mp4"); // k1 ile sarildi
        KeyProvider rotated = CryptoTestSupport.provider(
                "k1:" + CryptoTestSupport.b64(3) + ",k2:" + CryptoTestSupport.b64(4), "k2");
        PostVideoCipher after = new PostVideoCipher(rotated, new CryptoService(), CHUNK);
        assertTrue(after.newDek("post/n.mp4").wrapped().startsWith("k2:"));
        assertArrayEquals(dek.key().getEncoded(), after.unwrap(dek.wrapped(), "post/z.mp4").getEncoded());
        // k1 listeden cikarilirsa eski videolar acilmaz (docs/KEY_MANAGEMENT.md: eski anahtari SILMEYIN)
        KeyProvider dropped = CryptoTestSupport.provider("k2:" + CryptoTestSupport.b64(4), "k2");
        PostVideoCipher lost = new PostVideoCipher(dropped, new CryptoService(), CHUNK);
        assertThrows(CryptoException.class, () -> lost.unwrap(dek.wrapped(), "post/z.mp4"));
    }
}
