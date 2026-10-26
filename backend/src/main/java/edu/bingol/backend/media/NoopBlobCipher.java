package edu.bingol.backend.media;

/** Sifrelemeyen varsayilan {@link BlobCipher}; uygulamada baska bir BlobCipher bean'i varsa o kullanilir. */
public final class NoopBlobCipher implements BlobCipher {

    @Override
    public byte[] encrypt(byte[] plain, String context) {
        return plain;
    }

    @Override
    public byte[] decrypt(byte[] stored, String context) {
        return stored;
    }
}
