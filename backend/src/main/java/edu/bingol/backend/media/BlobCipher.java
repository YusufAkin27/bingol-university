package edu.bingol.backend.media;

/**
 * Ozel depoya yazilan baytlari diskte sifrelemek icin enjeksiyon noktasi. Varsayilan {@link NoopBlobCipher}
 * sifrelemez; ileride (T21/T8) baska bir {@code BlobCipher} bean'i tanimlanirsa varsayilanin yerini alir.
 */
public interface BlobCipher {

    /**
     * @param context "kova/anahtar" (ornek chat/ab12.jpg): AEAD'de ek dogrulanan veri olarak kullanilabilir
     * @return diske yazilacak baytlar
     */
    byte[] encrypt(byte[] plain, String context);

    /** {@link #encrypt} ciktisini cozer; ayni {@code context} ile cagrilir. */
    byte[] decrypt(byte[] stored, String context);
}
