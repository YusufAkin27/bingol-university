package edu.bingol.backend.crypto;

import edu.bingol.backend.crypto.ConversationKeyService.DekRef;
import edu.bingol.backend.crypto.CryptoException.Reason;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.Arrays;
import javax.crypto.Mac;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/**
 * Parcali AES-256-GCM. Bicim: "BUB1" | dekSurumu(4) | parcaBoyu(4) | tuz(16) | { uzunluk(4) | sifreliParca }*.
 * Her dosya icin alt anahtar = HMAC-SHA256(DEK, etiket || tuz) olur; boylece nonce'lar dosya icinde
 * sayac (64-bit) olabilir ve dosyalar arasi nonce cakismasi riski ortadan kalkar. Her parcanin AAD'si
 * baglam + baslik + "son parca mi" bayragidir: parca siralamasi/yeniden kullanimi sayacla, kesme
 * (truncation) son-parca bayragiyla yakalanir. Son parca bos olabilir (bos dosya = tek bos parca).
 */
@Component
public class ChunkedAesGcmBlobCipher implements BlobCipher {

    static final byte[] MAGIC = "BUB1".getBytes(StandardCharsets.US_ASCII);
    static final int DEFAULT_CHUNK = 64 * 1024;
    private static final int MAX_CHUNK = 1024 * 1024;
    private static final int SALT = 16;
    private static final byte[] KDF_LABEL = "bu-blob-v1".getBytes(StandardCharsets.US_ASCII);

    private final ConversationKeyService keys;
    private final CryptoService crypto;
    private final SecureRandom random = new SecureRandom();
    private final int chunkSize;

    @org.springframework.beans.factory.annotation.Autowired
    public ChunkedAesGcmBlobCipher(ConversationKeyService keys, CryptoService crypto) {
        this(keys, crypto, DEFAULT_CHUNK);
    }

    ChunkedAesGcmBlobCipher(ConversationKeyService keys, CryptoService crypto, int chunkSize) {
        this.keys = keys;
        this.crypto = crypto;
        this.chunkSize = chunkSize;
    }

    @Override
    public void encrypt(long conversationId, byte[] ctx, InputStream in, OutputStream out) throws IOException {
        DekRef dek = keys.active(conversationId);
        byte[] salt = new byte[SALT];
        random.nextBytes(salt);
        byte[] header = header(dek.version(), chunkSize, salt);
        out.write(header);
        SecretKey sub = subKey(dek.key(), salt);
        byte[] base = Aad.concat(Aad.of("blob", conversationId, ctx), header);

        byte[] cur = in.readNBytes(chunkSize);
        long counter = 0;
        while (true) {
            // Bir ilerisini okuyarak bu parcanin sonuncu olup olmadigini biliriz.
            byte[] next = cur.length < chunkSize ? new byte[0] : in.readNBytes(chunkSize);
            boolean last = next.length == 0;
            byte[] ct = crypto.encrypt(sub, nonce(counter), chunkAad(base, last), cur);
            DataOutputStream d = new DataOutputStream(out);
            d.writeInt(ct.length);
            d.write(ct);
            d.flush();
            if (last) {
                break;
            }
            cur = next;
            counter++;
        }
    }

    @Override
    public void decrypt(long conversationId, byte[] ctx, InputStream in, OutputStream out) throws IOException {
        DataInputStream d = new DataInputStream(in);
        byte[] header = new byte[MAGIC.length + 4 + 4 + SALT];
        try {
            d.readFully(header);
        } catch (java.io.EOFException e) {
            throw new CryptoException(Reason.MALFORMED, "Blob basligi eksik");
        }
        ByteBuffer hb = ByteBuffer.wrap(header);
        byte[] magic = new byte[MAGIC.length];
        hb.get(magic);
        int version = hb.getInt();
        int chunk = hb.getInt();
        byte[] salt = new byte[SALT];
        hb.get(salt);
        if (!Arrays.equals(magic, MAGIC) || chunk <= 0 || chunk > MAX_CHUNK) {
            throw new CryptoException(Reason.MALFORMED, "Blob basligi gecersiz");
        }
        SecretKey sub = subKey(keys.key(conversationId, version), salt);
        byte[] base = Aad.concat(Aad.of("blob", conversationId, ctx), header);
        int maxCt = chunk + CryptoService.TAG_BITS / 8;

        long counter = 0;
        byte[] ct = readChunk(d, maxCt, true);
        while (true) {
            byte[] nextLen = readLenOrEof(d);
            boolean last = nextLen == null;
            out.write(crypto.open(sub, chunkAad(base, last), nonce(counter), ct));
            if (last) {
                break;
            }
            ct = readChunkBody(d, ByteBuffer.wrap(nextLen).getInt(), maxCt);
            counter++;
        }
    }

    /** Ilk parcanin uzunluk alani zorunludur (en az bir parca vardir). */
    private static byte[] readChunk(DataInputStream d, int maxCt, boolean required) throws IOException {
        byte[] len = readLenOrEof(d);
        if (len == null) {
            throw new CryptoException(Reason.MALFORMED, "Blob govdesi eksik");
        }
        return readChunkBody(d, ByteBuffer.wrap(len).getInt(), maxCt);
    }

    /** 4 baytlik uzunluk; temiz EOF = null; yarim kalan = bozuk. */
    private static byte[] readLenOrEof(DataInputStream d) throws IOException {
        byte[] len = d.readNBytes(4);
        if (len.length == 0) {
            return null;
        }
        if (len.length < 4) {
            throw new CryptoException(Reason.MALFORMED, "Blob kesilmis");
        }
        return len;
    }

    private static byte[] readChunkBody(DataInputStream d, int n, int maxCt) throws IOException {
        if (n < CryptoService.TAG_BITS / 8 || n > maxCt) {
            throw new CryptoException(Reason.MALFORMED, "Blob parca uzunlugu gecersiz");
        }
        byte[] ct = d.readNBytes(n);
        if (ct.length < n) {
            throw new CryptoException(Reason.MALFORMED, "Blob kesilmis");
        }
        return ct;
    }

    private static byte[] header(int version, int chunk, byte[] salt) {
        return ByteBuffer.allocate(MAGIC.length + 4 + 4 + SALT).put(MAGIC).putInt(version).putInt(chunk).put(salt).array();
    }

    private static byte[] chunkAad(byte[] base, boolean last) {
        return Aad.concat(base, new byte[] {(byte) (last ? 1 : 0)});
    }

    private static byte[] nonce(long counter) {
        return ByteBuffer.allocate(CryptoService.NONCE_BYTES).putInt(0).putLong(counter).array();
    }

    private static SecretKey subKey(SecretKey dek, byte[] salt) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(dek.getEncoded(), "HmacSHA256"));
            mac.update(KDF_LABEL);
            return new SecretKeySpec(mac.doFinal(salt), "AES");
        } catch (GeneralSecurityException e) {
            throw new CryptoException(Reason.CONFIG, "Alt anahtar uretilemedi", e);
        }
    }
}
