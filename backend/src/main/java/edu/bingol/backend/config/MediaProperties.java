package edu.bingol.backend.config;

import edu.bingol.backend.media.ImageKind;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * `app.media.*`: gorsel hatti ayarlari. Bos/0 degerler varsayilana duser (application.properties ortam
 * degiskeniyle ezilebilir: MEDIA_AVATAR_MAX_STORED_BYTES vb.).
 *
 * @param maxPixels             kabul edilen en buyuk genislik*yukseklik (varsayilan 25 000 000)
 * @param concurrency           ayni anda islenen gorsel sayisi (bellek korumasi, varsayilan 2)
 * @param graceSeconds          yeni yazilan/dokunulan dosya bu sure dolmadan release ile silinmez (varsayilan 10)
 * @param orphanMinAgeHours     yetim temizligi bu yastan kucuk dosyalara dokunmaz (varsayilan 24)
 * @param thumbDimension        kucuk resmin uzun kenari (varsayilan 320)
 * @param privateDir            ozel depo kok dizini; bos ise `app.storage.dir`/_private
 * @param signingSecret         imzali URL anahtari; bos ise jwt.secret'tan turetilir
 * @param extraReferenceColumns "tablo.sutun" listesi: yetim temizliginin "kullaniliyor" saydigi ek sutunlar
 * @param sweepFolders          yetim temizligi taranan herkese acik klasorler
 * @param sweepEnabled          zamanlanmis temizlik acik mi (varsayilan true)
 */
@ConfigurationProperties("app.media")
public record MediaProperties(long maxPixels, int concurrency, int graceSeconds, int orphanMinAgeHours,
                              int thumbDimension, String privateDir, String signingSecret,
                              List<String> extraReferenceColumns, List<String> sweepFolders, Boolean sweepEnabled,
                              Limits avatar, Limits cover, Limits post, Limits chat) {

    /**
     * Tur bazli sinirlar.
     *
     * @param maxUploadBytes yuklenen HAM dosyanin ust siniri
     * @param maxDimension   uzun kenar (px)
     * @param maxStoredBytes SIKISTIRMA SONRASI saklanan dosyanin ust siniri (kalite dusurulur, gerekirse kucultulur)
     * @param jpegQuality    baslangic JPEG kalitesi (1-100)
     */
    public record Limits(long maxUploadBytes, int maxDimension, long maxStoredBytes, int jpegQuality) {

        public Limits {
            jpegQuality = jpegQuality <= 0 ? 85 : Math.min(jpegQuality, 100);
        }
    }

    public MediaProperties {
        maxPixels = maxPixels <= 0 ? 25_000_000L : maxPixels;
        concurrency = concurrency <= 0 ? 2 : concurrency;
        graceSeconds = graceSeconds <= 0 ? 10 : graceSeconds;
        orphanMinAgeHours = orphanMinAgeHours <= 0 ? 24 : orphanMinAgeHours;
        thumbDimension = thumbDimension <= 0 ? 320 : thumbDimension;
        extraReferenceColumns = extraReferenceColumns == null ? List.of() : List.copyOf(extraReferenceColumns);
        sweepFolders = sweepFolders == null || sweepFolders.isEmpty()
                ? List.of("avatars", "covers", "posts") : List.copyOf(sweepFolders);
        sweepEnabled = sweepEnabled == null || sweepEnabled;
        avatar = fill(avatar, 2L << 20, 512, 150L << 10);
        cover = fill(cover, 3L << 20, 1600, 400L << 10);
        post = fill(post, 3L << 20, 1600, 400L << 10);
        chat = fill(chat, 5L << 20, 1600, 500L << 10);
    }

    private static Limits fill(Limits l, long upload, int dim, long stored) {
        if (l == null) {
            return new Limits(upload, dim, stored, 85);
        }
        return new Limits(l.maxUploadBytes() <= 0 ? upload : l.maxUploadBytes(),
                l.maxDimension() <= 0 ? dim : l.maxDimension(),
                l.maxStoredBytes() <= 0 ? stored : l.maxStoredBytes(),
                l.jpegQuality());
    }

    public Limits limits(ImageKind kind) {
        return switch (kind) {
            case AVATAR -> avatar;
            case COVER -> cover;
            case POST -> post;
            case CHAT -> chat;
            // Gonderi gorseli: topluluk gonderisi sinirlarindan turetilir (ham 8 MB, saklanan en az 600 KB)
            case FEED -> new Limits(Math.max(post.maxUploadBytes(), 8L << 20), post.maxDimension(),
                    Math.max(post.maxStoredBytes(), 600L << 10), post.jpegQuality());
        };
    }
}
