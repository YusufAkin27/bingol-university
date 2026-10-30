package edu.bingol.backend.media;

/**
 * Ozel depodaki gorsel. `key`/`thumbKey` yalniz sunucu icidir (URL degildir); erisim icin
 * {@link PrivateMediaStore#serve} (yetki kontrolunden SONRA) veya {@link MediaUrlSigner} kullanilir.
 */
public record PrivateMedia(String bucket, String key, String thumbKey, int width, int height, long bytes,
                           String contentType, int thumbEdge) {

    public PrivateMedia(String bucket, String key, String thumbKey, int width, int height, long bytes,
                        String contentType) {
        this(bucket, key, thumbKey, width, height, bytes, contentType, 0);
    }
}
