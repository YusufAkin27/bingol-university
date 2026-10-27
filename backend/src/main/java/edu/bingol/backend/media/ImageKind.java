package edu.bingol.backend.media;

/**
 * Yuklenen gorselin amaci. Sinirlar (yukleme/saklama bayti, uzun kenar, kalite) `app.media.<tur>.*`
 * ayarlarindan gelir ({@link edu.bingol.backend.config.MediaProperties#limits}).
 */
public enum ImageKind {

    AVATAR("avatars"),
    /** Topluluk/etkinlik kapagi. */
    COVER("covers"),
    /** Topluluk gonderisi gorseli. */
    POST("posts"),
    /** Sohbet gorseli: herkese acik klasoru YOKTUR; yalnizca {@link PrivateMediaStore}. */
    CHAT(null),
    /** Genel gonderi (Kesfet akisi) gorseli: ozel depo (herkese acik klasor yok), uzun kenar 1600 px, onizleme 480 px. */
    FEED(null);

    private final String publicFolder;

    ImageKind(String publicFolder) {
        this.publicFolder = publicFolder;
    }

    /** /files/{klasor}/ altindaki herkese acik klasor; yoksa null. */
    public String publicFolder() {
        return publicFolder;
    }
}
