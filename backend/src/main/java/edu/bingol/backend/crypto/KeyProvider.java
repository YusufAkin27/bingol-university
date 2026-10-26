package edu.bingol.backend.crypto;

import java.util.Set;
import javax.crypto.SecretKey;

/** Ana anahtar (KEK) kaynagi. Gercek uygulama ortam degiskeni/dosya okur; ileride KMS ile degistirilebilir. */
public interface KeyProvider {

    /** Yeni DEK'leri saran anahtarin kimligi. */
    String activeKeyId();

    /** Bilinmeyen kimlik icin KEY_UNAVAILABLE firlatir. */
    SecretKey key(String id);

    Set<String> keyIds();

    /** Yalnizca yerel gelistirme icin gomulu anahtar kullaniliyorsa true. */
    boolean isDevKey();
}
