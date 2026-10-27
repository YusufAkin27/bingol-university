package edu.bingol.backend.post.social;

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

/** Metinde etiketlenen kullanici. commentId null = gonderi metni. */
@Entity
@Table(name = "post_mention")
@Getter
@Setter
@NoArgsConstructor
public class PostMention {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "post_id", nullable = false)
    private Long postId;

    @Column(name = "comment_id")
    private Long commentId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public PostMention(Long postId, Long commentId, Long userId) {
        this.postId = postId;
        this.commentId = commentId;
        this.userId = userId;
    }
}
