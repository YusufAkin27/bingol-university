package edu.bingol.backend.forum.topic;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Kaydedilen konu ya da yorum (TOPIC | COMMENT). Tabloyu A tanimlar; yorum kaydetmeyi B kullanir. */
@Entity
@Table(name = "forum_bookmark")
@Getter
@Setter
@NoArgsConstructor
public class ForumBookmark {

    public static final String TOPIC = "TOPIC";
    public static final String COMMENT = "COMMENT";

    @EmbeddedId
    private ForumBookmarkId id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public ForumBookmark(Long userId, String targetType, Long targetId) {
        this.id = new ForumBookmarkId(userId, targetType, targetId);
    }
}
