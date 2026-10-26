package edu.bingol.backend.moderation;

/**
 * Moderasyon kuyrugunda yoneticiye gosterilen icerik onizlemesi. Gorsel turlerde `url`/`thumbnailUrl` yoneticiye
 * ozel (yetkili) bir uctan servis edilen adres olmalidir; herkese acik adres gerekmez. Metin turlerinde `text`.
 */
public record MediaPreview(String kind, String url, String thumbnailUrl, String mime, String text) {

    public static MediaPreview image(String url, String thumbnailUrl, String mime) {
        return new MediaPreview("IMAGE", url, thumbnailUrl, mime, null);
    }

    public static MediaPreview text(String text) {
        return new MediaPreview("TEXT", null, null, null, text);
    }
}
