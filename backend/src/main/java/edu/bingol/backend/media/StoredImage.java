package edu.bingol.backend.media;

/** Herkese acik depoya yazilmis gorselin sonucu. `url`/`thumbUrl` goreli ve /files/** altindadir. */
public record StoredImage(String url, String thumbUrl, int width, int height, long bytes, String contentType) {
}
