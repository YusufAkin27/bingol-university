package edu.bingol.backend.crypto;

/** Sifreleme katmani hatasi. Mesaj ICERIK tasimaz (log'a guvenle yazilabilir). */
public class CryptoException extends RuntimeException {

    public enum Reason {
        /** Ana anahtar veya DEK bulunamadi / acilamadi. */
        KEY_UNAVAILABLE,
        /** Etiket dogrulanamadi: yanlis anahtar, kurcalanmis veri veya baglam (AAD) uyusmazligi. */
        AUTH_FAILED,
        /** Bicim bozuk (nonce uzunlugu, baslik vb.). */
        MALFORMED,
        /** Yapilandirma hatasi. */
        CONFIG
    }

    private final Reason reason;

    public CryptoException(Reason reason, String message) {
        super(message);
        this.reason = reason;
    }

    public CryptoException(Reason reason, String message, Throwable cause) {
        super(message, cause);
        this.reason = reason;
    }

    public Reason reason() {
        return reason;
    }
}
