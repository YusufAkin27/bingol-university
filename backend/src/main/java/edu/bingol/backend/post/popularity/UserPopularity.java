package edu.bingol.backend.post.popularity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Önbelleğe alınmış kullanıcı popülerlik puanı (tablo user_popularity; UserPopularityService saatlik günceller). */
@Entity
@Table(name = "user_popularity")
@Getter
@Setter
@NoArgsConstructor
public class UserPopularity {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Column(nullable = false)
    private short score;

    @Column(name = "follower_count", nullable = false)
    private int followerCount;

    @Column(name = "likes_received", nullable = false)
    private long likesReceived;

    @Column(name = "post_count", nullable = false)
    private int postCount;

    @Column(name = "computed_at", nullable = false)
    private Instant computedAt = Instant.now();
}
