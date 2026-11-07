package edu.bingol.backend.post;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Genel (kampus geneli) gonderi; kulup ici CommunityPost'tan ayridir. Sayaclar PostCounters ile atomik guncellenir. */
@Entity
@Table(name = "post")
@org.hibernate.annotations.DynamicUpdate
@Getter
@Setter
public class Post {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long authorId;

    @Column(columnDefinition = "TEXT")
    private String body;

    /** Istemci Idempotency-Key (V1540): ayni yazar + anahtar ikinci gonderi uretmez. Istemciye donmez. */
    @Column(length = 64)
    private String idempotencyKey;

    @Column(nullable = false)
    private int likeCount;

    @Column(nullable = false)
    private short mediaCount;

    /** Gorunur yorum + yanit sayisi (V1230; atomik SQL ile guncellenir: post.comment.CommentCounters). */
    @Column(nullable = false)
    private int commentCount;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Instant editedAt;

    private Instant deletedAt;

    private Long deletedBy;

    private Instant hiddenAt;

    @Column(length = 300)
    private String hiddenReason;

    /** Populerlik puani (saatlik is gunceller). */
    @Column(nullable = false)
    private double score;

    /** Kesfet "top" siralama puani (PostRankService; istemciye donmez). */
    @Column(nullable = false)
    private double rankScore;

    /** PHOTO | VIDEO: ilk medyanin turu (reels yalniz VIDEO okur). */
    @Column(nullable = false, length = 8)
    private String kind = KIND_PHOTO;

    /** Video izlenme sayisi (kullanici basina gonderi basina tek sayim). */
    @Column(nullable = false)
    private int viewCount;

    /** Izlenme basina izleme tamamlanma yuzdesi (0..100) toplami; ortalama = toplam / (izlenme * 100). */
    @Column(nullable = false)
    private long completionPctSum;

    /** Sahip begeni sayisini baskalarindan gizledi (V1670); sayi yalniz sahibine/yoneticiye doner. */
    @Column(nullable = false)
    private boolean hideLikeCount;

    /** Sahip yorumlari kapatti (V1670): yeni yorum/yanit/yorum begenisi 403 COMMENTS_DISABLED. */
    @Column(nullable = false)
    private boolean commentsDisabled;

    public static final String KIND_PHOTO = "PHOTO";
    public static final String KIND_VIDEO = "VIDEO";

    public boolean isVideo() {
        return KIND_VIDEO.equals(kind);
    }

    /** Ortalama izleme tamamlanma orani 0..1 (izlenme yoksa 0). */
    public double avgCompletion() {
        return viewCount <= 0 ? 0 : Math.min(1.0, completionPctSum / (100.0 * viewCount));
    }

    public boolean isVisible() {
        return deletedAt == null && hiddenAt == null;
    }
}
