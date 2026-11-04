package edu.bingol.backend.post.reels;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Kullanıcı bazlı izleme geçmişi (tablo post_watch; Reels önerisi + "ilgilenmiyorum"). Kısa saklama (45 gün,
 * PostWatchRetentionJob), hesap silinince silinir, dışa aktarıma girer. Beğeni/yorum/kaydetme durumu burada tutulmaz
 * (kendi tablolarından okunur): kişisel veri minimal.
 */
@Entity
@Table(name = "post_watch")
@Getter
@Setter
@NoArgsConstructor
public class PostWatch {

    @EmbeddedId
    private PostWatchId id;

    @Column(name = "first_seen_at", nullable = false)
    private Instant firstSeenAt = Instant.now();

    @Column(name = "last_seen_at", nullable = false)
    private Instant lastSeenAt = Instant.now();

    /** Ekranda gösterilme sayısı. */
    @Column(nullable = false)
    private int impressions;

    /** Toplam izleme süresi (ms). */
    @Column(name = "watch_ms", nullable = false)
    private long watchMs;

    /** En yüksek izleme tamamlanma yüzdesi (0..100). */
    @Column(name = "completion_pct", nullable = false)
    private short completionPct;

    /** Hızlı geçilme sayısı. */
    @Column(nullable = false)
    private int skips;

    @Column(name = "not_interested", nullable = false)
    private boolean notInterested;

    public PostWatch(Long userId, Long postId) {
        this.id = new PostWatchId(userId, postId);
    }
}
