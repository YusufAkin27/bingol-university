package edu.bingol.backend.news;

import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "news_item", indexes = {
        @Index(columnList = "type, publishedDate"),
        @Index(columnList = "publishedDate")
})
@Getter
@Setter
public class NewsItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private ContentType type;

    @Column(nullable = false, unique = true, length = 1000)
    private String url;

    @Column(nullable = false, length = 1000)
    private String title;

    @Column(length = 600)
    private String summary;

    /** Duz metin icerik (harici sitelerdeki duyurularda bos olabilir). */
    @Column(columnDefinition = "TEXT")
    private String content;

    @Column(length = 1000)
    private String imageUrl;

    /** Liste tarihi; ayristirilamazsa cekim gunu (fetchedAt, Istanbul) yazilir. */
    private LocalDate publishedDate;

    /** Yalnizca ETKINLIK: detay sayfasinda etiketli bulunan baslangic tarihi (yoksa null). */
    private LocalDate eventDate;

    /** Detay (icerik) cekimi denemeleri; content bos kalan kayitlar sinirli sayida yeniden denenir. */
    @Column(nullable = false)
    private int contentAttempts;

    private Instant contentAttemptedAt;

    /** Yonetici gizlediyse herkese acik liste/detay/arama/favorilerde gorunmez. */
    @Column(nullable = false)
    private boolean hidden;

    @Column(nullable = false)
    private Instant fetchedAt;
}
