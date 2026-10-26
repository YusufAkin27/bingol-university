package edu.bingol.backend.crypto;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Arrays;
import java.util.Random;
import org.junit.jupiter.api.Test;

class BlobCipherTest {

    private final CryptoTestSupport t = new CryptoTestSupport();
    private final ConversationKeyService ks =
            t.keyService(CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(3), ""));
    // Kucuk parca boyu: sinir durumlari (tam kat, bir fazla/eksik) hizli denensin
    private final ChunkedAesGcmBlobCipher blob = new ChunkedAesGcmBlobCipher(ks, t.crypto, 1000);
    private static final byte[] CTX = {9, 9};

    private byte[] enc(long cid, byte[] ctx, byte[] data) throws IOException {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        blob.encrypt(cid, ctx, new ByteArrayInputStream(data), o);
        return o.toByteArray();
    }

    private byte[] dec(long cid, byte[] ctx, byte[] sealed) throws IOException {
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        blob.decrypt(cid, ctx, new ByteArrayInputStream(sealed), o);
        return o.toByteArray();
    }

    @Test
    void roundTripAtChunkBoundaries() throws Exception {
        Random r = new Random(1);
        for (int n : new int[] {0, 1, 999, 1000, 1001, 2000, 2001, 12_345}) {
            byte[] data = new byte[n];
            r.nextBytes(data);
            assertArrayEquals(data, dec(1, CTX, enc(1, CTX, data)), "n=" + n);
        }
    }

    @Test
    void largeBlobWithDefaultChunkSize() throws Exception {
        ChunkedAesGcmBlobCipher def = new ChunkedAesGcmBlobCipher(ks, t.crypto);
        byte[] data = new byte[3_000_000];
        new Random(2).nextBytes(data);
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        def.encrypt(5, CTX, new ByteArrayInputStream(data), o);
        ByteArrayOutputStream back = new ByteArrayOutputStream();
        def.decrypt(5, CTX, new ByteArrayInputStream(o.toByteArray()), back);
        assertArrayEquals(data, back.toByteArray());
    }

    @Test
    void sameInputEncryptsDifferently() throws Exception {
        byte[] data = "ayni".getBytes();
        assertFalse(Arrays.equals(enc(1, CTX, data), enc(1, CTX, data)));
    }

    @Test
    void anyBitFlipIsDetected() throws Exception {
        byte[] data = new byte[2500];
        new Random(3).nextBytes(data);
        byte[] sealed = enc(1, CTX, data);
        Random r = new Random(4);
        for (int i = 0; i < 300; i++) {
            byte[] bad = sealed.clone();
            bad[r.nextInt(bad.length)] ^= (byte) (1 << r.nextInt(8));
            assertThrows(RuntimeException.class, () -> dec(1, CTX, bad)); // CryptoException
        }
    }

    @Test
    void truncationAndAppendAreDetected() throws Exception {
        byte[] data = new byte[3500];
        new Random(5).nextBytes(data);
        byte[] sealed = enc(1, CTX, data);
        // Her olasi kesme noktasi (parca sinirlari dahil)
        for (int cut = 0; cut < sealed.length; cut += 7) {
            byte[] c = Arrays.copyOf(sealed, cut);
            assertThrows(CryptoException.class, () -> dec(1, CTX, c), "cut=" + cut);
        }
        byte[] extra = Arrays.copyOf(sealed, sealed.length + 20);
        assertThrows(CryptoException.class, () -> dec(1, CTX, extra));
    }

    @Test
    void chunkReorderIsDetected() throws Exception {
        byte[] data = new byte[3000]; // 3 tam parca + bos son parca
        byte[] sealed = enc(1, CTX, data);
        int hdr = 4 + 4 + 4 + 16;
        int entry = 4 + 1000 + 16;
        byte[] swapped = sealed.clone();
        System.arraycopy(sealed, hdr + entry, swapped, hdr, entry);
        System.arraycopy(sealed, hdr, swapped, hdr + entry, entry);
        assertThrows(CryptoException.class, () -> dec(1, CTX, swapped));
    }

    @Test
    void wrongConversationOrContextFails() throws Exception {
        byte[] sealed = enc(1, CTX, "gorsel".getBytes());
        ks.active(2);
        assertThrows(CryptoException.class, () -> dec(2, CTX, sealed));
        assertThrows(CryptoException.class, () -> dec(1, new byte[] {1}, sealed));
        assertEquals("gorsel", new String(dec(1, CTX, sealed)));
    }

    @Test
    void garbageHeaderIsMalformed() {
        assertThrows(CryptoException.class, () -> dec(1, CTX, new byte[0]));
        assertThrows(CryptoException.class, () -> dec(1, CTX, new byte[100]));
        assertThrows(CryptoException.class, () -> dec(1, CTX, "BUB1".getBytes()));
    }
}
