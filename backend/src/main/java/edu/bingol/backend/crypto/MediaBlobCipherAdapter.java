package edu.bingol.backend.crypto;

import edu.bingol.backend.crypto.CryptoException.Reason;
import edu.bingol.backend.media.BlobCipher;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.Arrays;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import javax.crypto.Mac;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/**
 * T1 medya hattinin {@link BlobCipher} (bayt dizisi) arayuzunun gercek uygulamasi: ozel medya (sohbet gorselleri)
 * diske AES-256-GCM ile sifreli yazilir. Medya baglami "kova/anahtar" oldugundan konusma DEK'i degil, ana
 * anahtardan turetilen medya anahtari kullanilir (anahtar = HMAC(ana, "bu-media-v1")); AAD = baglam metni.
 * Cerceve: "BUM1" | anahtarIdUzunlugu(1) | anahtarId | nonce(12) | ciphertext+etiket.
 * Cok buyuk dosyalar icin akisli {@link edu.bingol.backend.crypto.BlobCipher} (konusma DEK'li) kullanilabilir.
 * Cerceve sihirli baytiyla baslamayan eski (sifrelenmemis) dosyalar oldugu gibi okunur (gecis donemi).
 */
@Component
public class MediaBlobCipherAdapter implements BlobCipher {

    private static final byte[] MAGIC = "BUM1".getBytes(StandardCharsets.US_ASCII);
    private static final byte[] LABEL = "bu-media-v1".getBytes(StandardCharsets.US_ASCII);

    private final KeyProvider keys;
    private final CryptoService crypto;
    private final Map<String, SecretKey> derived = new ConcurrentHashMap<>();

    public MediaBlobCipherAdapter(KeyProvider keys, CryptoService crypto) {
        this.keys = keys;
        this.crypto = crypto;
    }

    @Override
    public byte[] encrypt(byte[] plain, String context) {
        String kid = keys.activeKeyId();
        byte[] kidB = kid.getBytes(StandardCharsets.US_ASCII);
        byte[] nonce = crypto.newNonce();
        byte[] ct = crypto.encrypt(mediaKey(kid), nonce, aad(context), plain);
        return ByteBuffer.allocate(MAGIC.length + 1 + kidB.length + nonce.length + ct.length)
                .put(MAGIC).put((byte) kidB.length).put(kidB).put(nonce).put(ct).array();
    }

    @Override
    public byte[] decrypt(byte[] stored, String context) {
        if (stored.length < MAGIC.length || !Arrays.equals(Arrays.copyOf(stored, MAGIC.length), MAGIC)) {
            return stored; // sifrelenmemis eski dosya
        }
        try {
            ByteBuffer b = ByteBuffer.wrap(stored);
            b.position(MAGIC.length);
            byte[] kidB = new byte[b.get() & 0xff];
            b.get(kidB);
            byte[] nonce = new byte[CryptoService.NONCE_BYTES];
            b.get(nonce);
            byte[] ct = new byte[b.remaining()];
            b.get(ct);
            return crypto.open(mediaKey(new String(kidB, StandardCharsets.US_ASCII)), aad(context), nonce, ct);
        } catch (java.nio.BufferUnderflowException e) {
            throw new CryptoException(Reason.MALFORMED, "Medya cercevesi gecersiz");
        }
    }

    private SecretKey mediaKey(String kid) {
        SecretKey cached = derived.get(kid);
        if (cached != null) {
            return cached;
        }
        SecretKey master = keys.key(kid);
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(master.getEncoded(), "HmacSHA256"));
            SecretKey k = new SecretKeySpec(mac.doFinal(LABEL), "AES");
            derived.put(kid, k);
            return k;
        } catch (GeneralSecurityException e) {
            throw new CryptoException(Reason.CONFIG, "Medya anahtari turetilemedi", e);
        }
    }

    private static byte[] aad(String context) {
        return Aad.of("media", 0, context.getBytes(StandardCharsets.UTF_8));
    }
}
