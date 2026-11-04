package edu.bingol.backend.post.comment;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Bir kullanicinin bir yorumu begenisi (post_comment_like). */
@Entity
@Table(name = "post_comment_like")
@Getter
@Setter
@NoArgsConstructor
public class PostCommentLike {

    @EmbeddedId
    private PostCommentLikeId id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public PostCommentLike(Long commentId, Long userId) {
        this.id = new PostCommentLikeId(commentId, userId);
    }
}
