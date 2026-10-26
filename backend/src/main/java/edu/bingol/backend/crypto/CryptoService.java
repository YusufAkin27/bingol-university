package edu.bingol.backend.crypto;

import edu.bingol.backend.crypto.CryptoException.Reason;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import javax.crypto.AEADBadTagException;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import org.springframework.stereotype.Component;

/**
 * Dusuk seviye AES-256-GCM sarmalayicisi (JCE'nin standart ilkeli; kendi algoritmamiz YOK).
 * Rastgele 96-bit nonce, 128-bit etiket. Nonce her cagrida SecureRandom'dan gelir;
 * DEK konusma basina oldugu icin tek anahtarla 2^32'den cok sifreleme beklenmez.
 */
@Component
public class CryptoService {

    public static final int NONCE_BYTES = 12;
    public static final int TAG_BITS = 128;
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";

    private final SecureRandom random = new SecureRandom();

    public byte[] newNonce() {
        byte[] n = new byte[NONCE_BYTES];
        random.nextBytes(n);
        return n;
    }

    /** Yeni rastgele 256-bit anahtar (DEK). */
    public byte[] newKeyBytes() {
        byte[] k = new byte[32];
        random.nextBytes(k);
        return k;
    }

    public Sealed seal(SecretKey key, byte[] aad, byte[] plaintext, int keyVersion) {
        byte[] nonce = newNonce();
        return new Sealed(encrypt(key, nonce, aad, plaintext), nonce, keyVersion);
    }

    /** Verilen nonce ile sifreler (parcali sifrelemede sayac nonce'u icin). */
    public byte[] encrypt(SecretKey key, byte[] nonce, byte[] aad, byte[] plaintext) {
        try {
            Cipher c = Cipher.getInstance(TRANSFORMATION);
            c.init(Cipher.ENCRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, nonce));
            c.updateAAD(aad);
            return c.doFinal(plaintext);
        } catch (GeneralSecurityException e) {
            throw new CryptoException(Reason.CONFIG, "AES-GCM sifreleme basarisiz", e);
        }
    }

    public byte[] open(SecretKey key, byte[] aad, byte[] nonce, byte[] ciphertext) {
        if (nonce == null || nonce.length != NONCE_BYTES || ciphertext == null || ciphertext.length < TAG_BITS / 8) {
            throw new CryptoException(Reason.MALFORMED, "Sifreli veri bicimi gecersiz");
        }
        try {
            Cipher c = Cipher.getInstance(TRANSFORMATION);
            c.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(TAG_BITS, nonce));
            c.updateAAD(aad);
            return c.doFinal(ciphertext);
        } catch (AEADBadTagException e) {
            throw new CryptoException(Reason.AUTH_FAILED, "Etiket dogrulanamadi", e);
        } catch (GeneralSecurityException e) {
            throw new CryptoException(Reason.MALFORMED, "AES-GCM cozme basarisiz", e);
        }
    }
}
