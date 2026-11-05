package edu.bingol.backend.forum.media;

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
 * Forum gorseli (tablo forum_media). Baytlar ozel depoda (kova "forum"); burada anahtar + meta veri.
 * Bir konuya baglanmis mi bilgisi forum_topic_image satirindadir (baglanmamis = yalniz yukleyen gorur).
 */
@Entity
@Table(name = "forum_media")
@Getter
@Setter
public class ForumMedia {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long ownerId;

    @Column(nullable = false, length = 300)
    private String storageKey;

    @Column(length = 300)
    private String thumbKey;

    @Column(nullable = false, length = 80)
    private String contentType;

    private Integer width;

    private Integer height;

    @Column(nullable = false)
    private long bytes;

    @Column(length = 64)
    private String sha256;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    /** Moderasyon gizlemesi: erisim kapanir. */
    private Instant hiddenAt;
}
