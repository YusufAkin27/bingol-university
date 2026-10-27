package edu.bingol.backend.media;

import edu.bingol.backend.crypto.CryptoException;
import edu.bingol.backend.crypto.CryptoException.Reason;
import edu.bingol.backend.crypto.CryptoService;
import edu.bingol.backend.crypto.KeyProvider;
import edu.bingol.backend.crypto.Sealed;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.Base64;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/**
 * Gonderi videolari icin dosya-basina-anahtarli (DEK) sifreleme. Sohbet videolarindan farki: konusma anahtari
 * yoktur; her dosyanin rastgele DEK'i ana anahtarla (KEK, {@code CRYPTO_MASTER_KEYS}) sarilip
 * {@code post_media.wrapped_dek} kolonuna yazilir.
 *
 * <p>Bicim (RASTGELE ERISIMLI): "BUP1" | parcaBoyu(4) | { AES-256-GCM(parca) + etiket(16) }*. Parcalar
 * SABIT boyutludur (son parca kisa olabilir), bu yuzden Range istegi dogrudan ilgili parcaya konumlanir; tum
 * dosya cozulmez. Nonce = 64-bit parca sayaci (DEK dosya basina tekil oldugundan cakisma olmaz). Her parcanin
 * AAD'si baglam + baslik + "son parca mi" bayragidir: siralama/kesme/baska dosyaya tasima GCM etiketiyle yakalanir.
 * Sarili DEK'in AAD'si baglami ("kova/anahtar") icerir: satirdaki wrapped_dek baska bir satira kopyalanamaz.
 *
 * <p>Sarili DEK metni: {@code <anaAnahtarKimligi>:<base64url(nonce||sifreli)>}. Ana anahtar rotasyonunda eski
 * anahtarlar listede KALMALIDIR (docs/KEY_MANAGEMENT.md).
 */
@Component
public class PostVideoCipher {

    static final byte[] MAGIC = "BUP1".getBytes(StandardCharsets.US_ASCII);
    static final int HEADER = MAGIC.length + 4;
    static final int DEFAULT_CHUNK = 64 * 1024;
    private static final int MAX_CHUNK = 1024 * 1024;
    private static final int TAG = CryptoService.TAG_BITS / 8;

    /** Yeni DEK ve onun sarili metni. */
    public record Dek(SecretKey key, String wrapped) {
    }

    private final KeyProvider keys;
    private final CryptoService crypto;
    private final int chunk;

    @org.springframework.beans.factory.annotation.Autowired
    public PostVideoCipher(KeyProvider keys, CryptoService crypto) {
        this(keys, crypto, DEFAULT_CHUNK);
    }

    PostVideoCipher(KeyProvider keys, CryptoService crypto, int chunk) {
        this.keys = keys;
        this.crypto = crypto;
        this.chunk = chunk;
    }

    /** Rastgele DEK uretir ve aktif ana anahtarla sarar. */
    public Dek newDek(String ctx) {
        byte[] raw = crypto.newKeyBytes();
        String kid = keys.activeKeyId();
        Sealed s = crypto.seal(keys.key(kid), wrapAad(ctx), raw, 1);
        byte[] blob = ByteBuffer.allocate(s.nonce().length + s.ciphertext().length).put(s.nonce())
                .put(s.ciphertext()).array();
        return new Dek(new SecretKeySpec(raw, "AES"), kid + ":" + Base64.getUrlEncoder().withoutPadding()
                .encodeToString(blob));
    }

    /** Sarili DEK'i cozer; baglam uyusmazsa/anahtar yoksa/bozuksa CryptoException. */
    public SecretKey unwrap(String wrapped, String ctx) {
        if (wrapped == null) {
            throw new CryptoException(Reason.MALFORMED, "Sarili anahtar yok");
        }
        int i = wrapped.indexOf(':');
        if (i <= 0) {
            throw new CryptoException(Reason.MALFORMED, "Sarili anahtar bicimi gecersiz");
        }
        byte[] blob;
        try {
            blob = Base64.getUrlDecoder().decode(wrapped.substring(i + 1));
        } catch (IllegalArgumentException e) {
            throw new CryptoException(Reason.MALFORMED, "Sarili anahtar bicimi gecersiz");
        }
        if (blob.length <= CryptoService.NONCE_BYTES) {
            throw new CryptoException(Reason.MALFORMED, "Sarili anahtar bicimi gecersiz");
        }
        byte[] nonce = Arrays.copyOfRange(blob, 0, CryptoService.NONCE_BYTES);
        byte[] ct = Arrays.copyOfRange(blob, CryptoService.NONCE_BYTES, blob.length);
        byte[] raw = crypto.open(keys.key(wrapped.substring(0, i)), wrapAad(ctx), nonce, ct);
        return new SecretKeySpec(raw, "AES");
    }

    /** Diske yazilacak toplam bayt (duz boyuttan). */
    public long sealedSize(long plainLength) {
        long n = Math.max(1, (plainLength + chunk - 1) / chunk);
        return HEADER + plainLength + n * TAG;
    }

    public void encrypt(SecretKey dek, String ctx, InputStream in, OutputStream out) throws IOException {
        byte[] header = ByteBuffer.allocate(HEADER).put(MAGIC).putInt(chunk).array();
        out.write(header);
        byte[] cur = in.readNBytes(chunk);
        long counter = 0;
        while (true) {
            byte[] next = cur.length < chunk ? new byte[0] : in.readNBytes(chunk);
            boolean last = next.length == 0;
            out.write(crypto.encrypt(dek, nonce(counter), chunkAad(ctx, header, last), cur));
            if (last) {
                break;
            }
            cur = next;
            counter++;
        }
    }

    /**
     * Duz iceriğin [start, end] (dahil) araligini `out`a yazar. Yalniz ilgili parcalar okunur/cozulur.
     * Dosya kesilmis ya da bozuksa CryptoException; cikti kismi olabilir (cagiran atmalidir).
     */
    public void decryptRange(Path file, SecretKey dek, String ctx, long start, long end, OutputStream out)
            throws IOException {
        try (RandomAccessFile f = new RandomAccessFile(file.toFile(), "r")) {
            long size = f.length();
            byte[] header = new byte[HEADER];
            if (size < HEADER + TAG) {
                throw new CryptoException(Reason.MALFORMED, "Video blob'u kisa");
            }
            f.readFully(header);
            ByteBuffer hb = ByteBuffer.wrap(header);
            byte[] magic = new byte[MAGIC.length];
            hb.get(magic);
            int ch = hb.getInt();
            if (!Arrays.equals(magic, MAGIC) || ch <= 0 || ch > MAX_CHUNK) {
                throw new CryptoException(Reason.MALFORMED, "Video blob basligi gecersiz");
            }
            long ctLen = (long) ch + TAG;
            long body = size - HEADER;
            long chunks = (body + ctLen - 1) / ctLen;
            long first = Math.max(0, start) / ch;
            long maxIdx = Math.min(chunks - 1, Math.max(end, 0) / ch);
            f.seek(HEADER + first * ctLen);
            for (long idx = first; idx <= maxIdx; idx++) {
                boolean last = idx == chunks - 1;
                int n = (int) (last ? body - idx * ctLen : ctLen);
                if (n < TAG) {
                    throw new CryptoException(Reason.MALFORMED, "Video blob parcasi gecersiz");
                }
                byte[] ct = new byte[n];
                f.readFully(ct);
                byte[] plain = crypto.open(dek, chunkAad(ctx, header, last), nonce(idx), ct);
                long from = Math.max(start, idx * (long) ch);
                long to = Math.min(end, idx * (long) ch + plain.length - 1);
                if (to >= from) {
                    out.write(plain, (int) (from - idx * (long) ch), (int) (to - from + 1));
                }
            }
        }
    }

    private static byte[] wrapAad(String ctx) {
        return ("bu-post-dek|" + ctx).getBytes(StandardCharsets.UTF_8);
    }

    private static byte[] chunkAad(String ctx, byte[] header, boolean last) {
        byte[] c = ctx.getBytes(StandardCharsets.UTF_8);
        ByteBuffer b = ByteBuffer.allocate(4 + 4 + c.length + header.length + 1);
        b.put("bup1".getBytes(StandardCharsets.US_ASCII)).putInt(c.length).put(c).put(header).put((byte) (last ? 1 : 0));
        return b.array();
    }

    private static byte[] nonce(long counter) {
        return ByteBuffer.allocate(CryptoService.NONCE_BYTES).putInt(0).putLong(counter).array();
    }
}
