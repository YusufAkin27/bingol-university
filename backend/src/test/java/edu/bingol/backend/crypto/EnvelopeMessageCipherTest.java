package edu.bingol.backend.crypto;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.crypto.CryptoException.Reason;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.stream.IntStream;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.Test;

class EnvelopeMessageCipherTest {

    private final CryptoTestSupport t = new CryptoTestSupport();
    private final KeyProvider kp = CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(1), "");
    private final ConversationKeyService ks = t.keyService(kp);
    private final EnvelopeMessageCipher cipher = t.cipher(ks);
    private static final byte[] CTX = {0, 0, 0, 0, 0, 0, 0, 42};

    @Test
    void roundTripIncludingUnicodeEmptyAndLarge() {
        for (String s : List.of("merhaba", "", "Türkçe ığüşöç İĞÜŞÖÇ", "مرحبا بالعالم", "emoji 😀🚀",
                "a".repeat(5_000_000))) {
            Sealed sealed = cipher.encryptText(7, CTX, s);
            assertEquals(s, cipher.decryptText(7, CTX, sealed));
            assertEquals(12, sealed.nonce().length);
            assertEquals(s.getBytes(StandardCharsets.UTF_8).length + 16, sealed.ciphertext().length);
        }
    }

    @Test
    void ciphertextDoesNotContainPlaintext() {
        String secret = "cok-gizli-ifade-1234567890";
        Sealed s = cipher.encryptText(1, CTX, secret);
        String hex = new String(s.ciphertext(), StandardCharsets.ISO_8859_1);
        assertFalse(hex.contains(secret));
    }

    @Test
    void samePlaintextGivesDifferentCiphertext() {
        Sealed a = cipher.encryptText(1, CTX, "ayni");
        Sealed b = cipher.encryptText(1, CTX, "ayni");
        assertFalse(Arrays.equals(a.ciphertext(), b.ciphertext()));
        assertFalse(Arrays.equals(a.nonce(), b.nonce()));
    }

    @Test
    void tamperedTagOrBodyOrNonceIsDetected() {
        Sealed s = cipher.encryptText(1, CTX, "kurcalanamaz");
        for (int i = 0; i < s.ciphertext().length; i++) {
            byte[] ct = s.ciphertext().clone();
            ct[i] ^= 0x01;
            CryptoException e = assertThrows(CryptoException.class,
                    () -> cipher.decrypt(1, CTX, new Sealed(ct, s.nonce(), s.keyVersion())));
            assertEquals(Reason.AUTH_FAILED, e.reason());
        }
        byte[] n = s.nonce().clone();
        n[0] ^= 1;
        assertThrows(CryptoException.class, () -> cipher.decrypt(1, CTX, new Sealed(s.ciphertext(), n, s.keyVersion())));
        // Kesilmis etiket
        byte[] cut = Arrays.copyOf(s.ciphertext(), s.ciphertext().length - 1);
        assertThrows(CryptoException.class, () -> cipher.decrypt(1, CTX, new Sealed(cut, s.nonce(), s.keyVersion())));
        assertEquals(Reason.MALFORMED, assertThrows(CryptoException.class,
                () -> cipher.decrypt(1, CTX, new Sealed(new byte[3], s.nonce(), s.keyVersion()))).reason());
    }

    @Test
    void movedToAnotherConversationOrContextDoesNotDecrypt() {
        Sealed s = cipher.encryptText(1, CTX, "baska yere tasinamaz");
        // Baska konusma: hem AAD hem DEK farkli
        cipher.encryptText(2, CTX, "dummy"); // konusma 2 DEK'i olussun
        Sealed moved = new Sealed(s.ciphertext(), s.nonce(), s.keyVersion());
        assertEquals(Reason.AUTH_FAILED, assertThrows(CryptoException.class, () -> cipher.decrypt(2, CTX, moved)).reason());
        // Ayni konusma, baska mesaj baglami
        byte[] otherCtx = {0, 0, 0, 0, 0, 0, 0, 43};
        assertEquals(Reason.AUTH_FAILED, assertThrows(CryptoException.class, () -> cipher.decrypt(1, otherCtx, s)).reason());
        // Ayni DEK ile bile AAD uyusmazligi: dogrudan CryptoService
        var dek = ks.active(1);
        byte[] aadOther = Aad.of("msg", 99, CTX);
        assertThrows(CryptoException.class, () -> t.crypto.open(dek.key(), aadOther, s.nonce(), s.ciphertext()));
    }

    @Test
    void aadFieldsAreUnambiguous() {
        assertFalse(Arrays.equals(Aad.of("a", 1, new byte[] {1, 2}), Aad.of("a", 1, new byte[] {1})));
        assertFalse(Arrays.equals(Aad.of("ab", 1, new byte[] {1}), Aad.of("a", 1, new byte[] {'b', 1})));
    }

    @Test
    void noNonceRepeatsInHundredThousandEncryptions() {
        var dek = ks.active(5);
        Set<String> seen = new HashSet<>();
        byte[] aad = Aad.of("msg", 5, CTX);
        for (int i = 0; i < 100_000; i++) {
            Sealed s = t.crypto.seal(dek.key(), aad, new byte[] {1}, dek.version());
            assertTrue(seen.add(java.util.HexFormat.of().formatHex(s.nonce())), "nonce tekrari: " + i);
        }
    }

    @Test
    void wrongKeyDoesNotDecrypt() {
        Sealed s = cipher.encryptText(1, CTX, "gizli");
        // Ayni veritabani, farkli ana anahtar: DEK acilamaz
        ConversationKeyService other = t.keyService(CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(2), ""));
        EnvelopeMessageCipher c2 = t.cipher(other);
        assertEquals(Reason.AUTH_FAILED, assertThrows(CryptoException.class, () -> c2.decrypt(1, CTX, s)).reason());
        // Sarili DEK'in master_key_id'si yeni sagliyicida yok
        ConversationKeyService missing = t.keyService(CryptoTestSupport.provider("zzz:" + CryptoTestSupport.b64(1), ""));
        assertEquals(Reason.KEY_UNAVAILABLE,
                assertThrows(CryptoException.class, () -> t.cipher(missing).decrypt(1, CTX, s)).reason());
        // Hic DEK'i olmayan konusma / surum
        assertEquals(Reason.KEY_UNAVAILABLE, assertThrows(CryptoException.class,
                () -> cipher.decrypt(999, CTX, new Sealed(new byte[32], new byte[12], 1))).reason());
        assertEquals(Reason.KEY_UNAVAILABLE, assertThrows(CryptoException.class,
                () -> cipher.decrypt(1, CTX, new Sealed(s.ciphertext(), s.nonce(), 9))).reason());
        // Dogrudan yanlis AES anahtari
        assertThrows(CryptoException.class, () -> t.crypto.open(new SecretKeySpec(new byte[32], "AES"),
                Aad.of("msg", 1, CTX), s.nonce(), s.ciphertext()));
    }

    @Test
    void failuresAreCountedWithoutContent() {
        Sealed s = cipher.encryptText(1, CTX, "x");
        byte[] ct = s.ciphertext().clone();
        ct[0] ^= 1;
        assertThrows(CryptoException.class, () -> cipher.decrypt(1, CTX, new Sealed(ct, s.nonce(), s.keyVersion())));
        // CryptoTestSupport.metrics kendi kayit defterine sahip; sayac artmis olmali
        assertEquals(1.0, t.registry.counter("crypto_failures_total", "reason", "decrypt_auth_failed").count());
    }

    @Test
    void dekIsCreatedOncePerConversationAndSurvivesCacheMiss() {
        var a = ks.active(11);
        var b = ks.active(11);
        assertEquals(a.version(), b.version());
        assertArrayEquals(a.key().getEncoded(), b.key().getEncoded());
        ks.clearCache();
        assertArrayEquals(a.key().getEncoded(), ks.active(11).key().getEncoded());
        assertNotEquals(Arrays.toString(a.key().getEncoded()), Arrays.toString(ks.active(12).key().getEncoded()));
        // Veritabaninda ham DEK yok
        byte[] wrapped = t.jdbc.queryForObject("SELECT wrapped_key FROM conversation_key WHERE conversation_id = 11",
                byte[].class);
        assertEquals(12 + 32 + 16, wrapped.length);
        assertFalse(new String(wrapped, StandardCharsets.ISO_8859_1)
                .contains(new String(a.key().getEncoded(), StandardCharsets.ISO_8859_1)));
    }

    @Test
    void cacheExpiresByTtl() {
        long[] now = {1_000};
        ConversationKeyService s = t.keyService(kp, () -> now[0], 10);
        var first = s.active(21);
        // TTL icinde veritabani silinse bile bellekten gelir
        t.jdbc.update("DELETE FROM conversation_key WHERE conversation_id = 21");
        assertArrayEquals(first.key().getEncoded(), s.key(21, 1).getEncoded());
        now[0] += 11_000;
        assertEquals(Reason.KEY_UNAVAILABLE, assertThrows(CryptoException.class, () -> s.key(21, 1)).reason());
    }

    @Test
    void concurrentEncryptDecryptAndFirstUseRace() throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(16);
        try {
            // 1) Ayni yeni konusmada es zamanli ilk kullanim: tek DEK uretilmeli
            List<Callable<Sealed>> first = new ArrayList<>();
            for (int i = 0; i < 32; i++) {
                int n = i;
                first.add(() -> cipher.encryptText(77, CTX, "mesaj " + n));
            }
            List<Sealed> sealed = new ArrayList<>();
            for (Future<Sealed> f : pool.invokeAll(first)) {
                sealed.add(f.get());
            }
            assertEquals(1, t.jdbc.queryForObject("SELECT COUNT(*) FROM conversation_key WHERE conversation_id = 77",
                    Integer.class));
            for (int i = 0; i < sealed.size(); i++) {
                assertEquals("mesaj " + i, cipher.decryptText(77, CTX, sealed.get(i)));
            }
            // 2) Yogun karisik is yuku
            List<Callable<Boolean>> work = new ArrayList<>();
            IntStream.range(0, 2000).forEach(i -> work.add(() -> {
                long cid = 100 + (i % 8);
                String m = "m" + i;
                return m.equals(cipher.decryptText(cid, CTX, cipher.encryptText(cid, CTX, m)));
            }));
            for (Future<Boolean> f : pool.invokeAll(work)) {
                assertTrue(f.get());
            }
        } finally {
            pool.shutdownNow();
        }
    }

    @Test
    void rotationRewrapsDeksWithoutTouchingMessages() {
        KeyProvider old = CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(1), "");
        ConversationKeyService ksOld = t.keyService(old);
        EnvelopeMessageCipher cOld = t.cipher(ksOld);
        List<Sealed> msgs = new ArrayList<>();
        for (long c = 1; c <= 450; c++) { // birden fazla sayfa (200'luk)
            msgs.add(cOld.encryptText(c, CTX, "eski " + c));
        }
        assertEquals(450L, ksOld.countsByMasterKey().get("k1"));

        // k2 eklendi ve aktif; k1 hala listede
        KeyProvider both = CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(1) + ",k2:" + CryptoTestSupport.b64(2), "");
        assertEquals("k2", both.activeKeyId());
        ConversationKeyService ksBoth = t.keyService(both);
        EnvelopeMessageCipher cBoth = t.cipher(ksBoth);
        // Yeni konusma artik k2 ile sarilir, eskiler hala acilir
        cBoth.encryptText(9000, CTX, "yeni");
        assertEquals("eski 5", cBoth.decryptText(5, CTX, msgs.get(4)));

        var r = ksBoth.rewrapAll("k2");
        assertEquals(450, r.rewrapped());
        assertEquals(0, r.failed());
        assertEquals(451L, ksBoth.countsByMasterKey().get("k2"));
        assertFalse(ksBoth.countsByMasterKey().containsKey("k1"));
        // Idempotent
        assertEquals(0, ksBoth.rewrapAll("k2").rewrapped());

        // k1 artik gerekli degil: yalniz k2 ile eski mesajlar (degistirilmemis) hala acilir
        EnvelopeMessageCipher cNew = t.cipher(t.keyService(CryptoTestSupport.provider("k2:" + CryptoTestSupport.b64(2), "")));
        for (int i = 0; i < msgs.size(); i++) {
            assertEquals("eski " + (i + 1), cNew.decryptText(i + 1, CTX, msgs.get(i)));
        }
        assertThrows(CryptoException.class, () -> ksBoth.rewrapAll("yok"));
    }

    @Test
    void rewrapFailureIsCountedNotFatal() {
        EnvelopeMessageCipher c1 = t.cipher(t.keyService(CryptoTestSupport.provider("k1:" + CryptoTestSupport.b64(1), "")));
        c1.encryptText(1, CTX, "a");
        c1.encryptText(2, CTX, "b");
        // k1 artik yok; k2/k3 var: eski DEK'ler acilamaz ama is durmaz
        ConversationKeyService ks23 = t.keyService(CryptoTestSupport.provider(
                "k2:" + CryptoTestSupport.b64(2) + ",k3:" + CryptoTestSupport.b64(3), ""));
        var r = ks23.rewrapAll("k3");
        assertEquals(0, r.rewrapped());
        assertEquals(2, r.failed());
    }
}
