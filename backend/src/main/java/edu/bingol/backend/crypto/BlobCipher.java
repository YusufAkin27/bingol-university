package edu.bingol.backend.crypto;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Buyuk ikili veri (sohbet gorselleri) icin akis sifreleme. Bellekte tum dosya tutulmaz.
 * Cozme sirasinda bir parca dogrulanmadan once onceki dogrulanmis parcalar yazilmis olabilir:
 * istisna gelirse cikti ATILMALIDIR (kismi dosyayi kullanma/servis etme).
 * Hatalar CryptoException; G/C hatalari IOException.
 */
public interface BlobCipher {

    void encrypt(long conversationId, byte[] contextBytes, InputStream in, OutputStream out) throws IOException;

    void decrypt(long conversationId, byte[] contextBytes, InputStream in, OutputStream out) throws IOException;
}
