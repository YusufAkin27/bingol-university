package edu.bingol.backend.post.media;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Gonderi medyasi (tablo post_media). Baytlar ozel depoda (`_private/post/`); burada anahtar + meta veri.
 * postId null = henuz bir gonderiye baglanmadi (yukleyen disinda kimse goremez).
 */
@Entity
@Table(name = "post_media")
@Getter
@Setter
public class PostMedia {

    public static final String IMAGE = "IMAGE";
    public static final String VIDEO = "VIDEO";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long postId;

    @Column(nullable = false)
    private Long ownerId;

    @Column(nullable = false, length = 8)
    private String kind = IMAGE;

    @Column(nullable = false)
    private short position;

    @Column(nullable = false, length = 300)
    private String storageKey;

    /** Gorselde onizleme; videoda poster (yoksa null). */
    @Column(length = 300)
    private String thumbKey;

    @Column(nullable = false, length = 80)
    private String contentType;

    private Integer width;

    private Integer height;

    /** Yalniz video: sure (ms). */
    private Integer durationMs;

    @Column(nullable = false)
    private long bytes;

    @Column(length = 64)
    private String sha256;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    /** Moderasyon gizlemesi: erisim kapanir, bayrak yeterlidir (anahtar degismez). */
    private Instant hiddenAt;

    /**
     * Video yeniden kodlama durumu (V360): null = donusturme yok (gorsel ya da ffmpeg kapali), PENDING, PROCESSING,
     * DONE, FAILED. PENDING/PROCESSING/FAILED iken orijinal video sunulur.
     */
    @Column(length = 12)
    private String transcodeStatus;

    /** Dosya-basina DEK'in ana anahtarla sarili hali (V360); null = diskte duz (eski kayit). */
    @Column(length = 400)
    private String wrappedDek;

    /** Baytlar {@code wrappedDek} ile sifreli mi (eski duz videolar false). */
    @Column(nullable = false)
    private boolean encrypted;

    @Column(nullable = false)
    private short transcodeAttempts;

    private Instant transcodeAt;

    /** Hikaye medyasi ise hikaye kimligi (post.story); dolu satir "baglanmamis yukleme" sayilmaz. */
    @Column(name = "story_id")
    private Long storyId;

    public boolean isVideo() {
        return VIDEO.equals(kind);
    }

    public boolean isHidden() {
        return hiddenAt != null;
    }
}
