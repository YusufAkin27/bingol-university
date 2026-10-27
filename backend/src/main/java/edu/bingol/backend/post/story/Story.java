package edu.bingol.backend.post.story;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Kisa omurlu (24 saat) hikaye. Medya post_media tablosunda (story_id ile baglanir). */
@Entity
@Table(name = "story")
@Getter
@Setter
@NoArgsConstructor
public class Story {

    public static final String IMAGE = "IMAGE";
    public static final String VIDEO = "VIDEO";
    public static final String TEXT = "TEXT";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "author_id", nullable = false)
    private Long authorId;

    @Column(nullable = false, length = 8)
    private String kind;

    @Column(name = "media_id")
    private Long mediaId;

    @Column(length = 200)
    private String caption;

    @Column(name = "body_text", length = 200)
    private String bodyText;

    @Column(length = 9)
    private String background;

    @Column(name = "view_count", nullable = false)
    private int viewCount;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    @Column(name = "hidden_at")
    private Instant hiddenAt;

    @Column(name = "hidden_reason", length = 300)
    private String hiddenReason;

    public boolean isLive(Instant now) {
        return deletedAt == null && hiddenAt == null && expiresAt.isAfter(now);
    }
}
