package edu.bingol.backend.crypto;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.crypto.CryptoException.Reason;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;

class BusAndMediaCipherTest {

    private final CryptoService crypto = new CryptoService();
    private final KeyProvider k1 = CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(1), "");
    private final BusCipher bus = new BusCipher(k1, crypto);
    private final MediaBlobCipherAdapter media = new MediaBlobCipherAdapter(k1, crypto);

    @Test
    void busRoundTripAndNoPlaintextInFrame() {
        String json = "{\"dest\":\"messages\",\"payload\":{\"text\":\"gizli üğ\"}}";
        String frame = bus.seal(json);
        assertFalse(frame.contains("gizli"));
        assertTrue(frame.startsWith("v1.k1."));
        assertEquals(json, bus.open(frame));
        assertFalse(frame.equals(bus.seal(json))); // her seferinde yeni nonce
    }

    @Test
    void busRejectsTamperedWrongKeyAndMalformedFrames() {
        String frame = bus.seal("{\"a\":1}");
        for (String bad : new String[] {null, "", "x", "v1.k1.", "v2.k1.AAAA", "v1.k1.!!!", frame + "A",
                frame.substring(0, frame.length() - 2)}) {
            assertThrows(CryptoException.class, () -> bus.open(bad), String.valueOf(bad));
        }
        // Baska ana anahtar: ayni kimlik, farkli anahtar
        BusCipher other = new BusCipher(CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(2), ""), crypto);
        assertEquals(Reason.AUTH_FAILED, assertThrows(CryptoException.class, () -> other.open(frame)).reason());
        // Bilinmeyen anahtar kimligi
        BusCipher unknown = new BusCipher(CryptoTestSupport.provider("zz:" + CryptoTestSupport.b64(1), ""), crypto);
        assertEquals(Reason.KEY_UNAVAILABLE, assertThrows(CryptoException.class, () -> unknown.open(frame)).reason());
    }

    @Test
    void busFramesSurviveKeyRotation() {
        String frame = bus.seal("{\"x\":1}");
        BusCipher rotated = new BusCipher(CryptoTestSupport.provider(
                "k1:" + CryptoTestSupport.b64(1) + ",k2:" + CryptoTestSupport.b64(2), ""), crypto);
        assertEquals("{\"x\":1}", rotated.open(frame));
        assertTrue(rotated.seal("{}").startsWith("v1.k2."));
    }

    @Test
    void mediaRoundTripEmptyAndLarge() {
        for (int n : new int[] {0, 1, 100_000, 3_000_000}) {
            byte[] data = new byte[n];
            new java.util.Random(n).nextBytes(data);
            byte[] stored = media.encrypt(data, "chat/ab12.jpg");
            assertEquals(n + 4 + 1 + 2 + 12 + 16, stored.length);
            assertArrayEquals(data, media.decrypt(stored, "chat/ab12.jpg"));
        }
    }

    @Test
    void mediaContextAndTamperingAreEnforced() {
        byte[] data = "JPEGDATA".getBytes(StandardCharsets.US_ASCII);
        byte[] stored = media.encrypt(data, "chat/a.jpg");
        assertThrows(CryptoException.class, () -> media.decrypt(stored, "chat/b.jpg")); // baska dosyaya tasima
        for (int i = 4; i < stored.length; i += 3) { // 0..3 sihirli bayt: bozulursa eski (sifresiz) dosya sayilir
            byte[] bad = stored.clone();
            bad[i] ^= 1;
            assertThrows(RuntimeException.class, () -> media.decrypt(bad, "chat/a.jpg"), "i=" + i);
        }
        assertThrows(CryptoException.class, () -> media.decrypt(java.util.Arrays.copyOf(stored, 8), "chat/a.jpg"));
    }

    @Test
    void mediaLegacyUnencryptedFilesPassThroughAndRotationKeepsOldFiles() {
        byte[] jpeg = {(byte) 0xFF, (byte) 0xD8, 1, 2, 3};
        assertArrayEquals(jpeg, media.decrypt(jpeg, "chat/old.jpg"));
        byte[] stored = media.encrypt(jpeg, "chat/n.jpg");
        MediaBlobCipherAdapter rotated = new MediaBlobCipherAdapter(CryptoTestSupport.provider(
                "k1:" + CryptoTestSupport.b64(1) + ",k2:" + CryptoTestSupport.b64(2), ""), crypto);
        assertArrayEquals(jpeg, rotated.decrypt(stored, "chat/n.jpg"));
    }
}
