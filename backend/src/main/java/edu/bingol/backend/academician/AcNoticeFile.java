package edu.bingol.backend.academician;

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
 * Duyuru dosyasi (V1904). Baytlar mevcut ozel medya deposunda (storageKey), burada yalniz ust veri. noticeId yuklemeden
 * sonra, duyuru olusurken doldurulur; bagsiz (bekleyen) satirlar 24 saat sonra temizlenir.
 */
@Entity
@Table(name = "ac_notice_file")
@Getter
@Setter
public class AcNoticeFile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long noticeId;

    @Column(nullable = false)
    private Long courseId;

    @Column(nullable = false, length = 80)
    private String storageKey;

    @Column(nullable = false, length = 200)
    private String originalName;

    /** SUNUCUNUN belirledigi tur (istemcinin bildirdigi degil). */
    @Column(nullable = false, length = 100)
    private String contentType;

    @Column(nullable = false)
    private long sizeBytes;

    private Long uploadedBy;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
