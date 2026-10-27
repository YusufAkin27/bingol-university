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

    @Column(nullable = false)
    private int likeCount;

    @Column(nullable = false)
    private int commentCount;

    @Column(nullable = false)
    private short mediaCount;

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

    public boolean isVisible() {
        return deletedAt == null && hiddenAt == null;
    }
}
