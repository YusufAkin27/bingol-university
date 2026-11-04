package edu.bingol.backend.post.comment;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** post_comment_like bilesik anahtari (comment_id, user_id). */
@Embeddable
@Getter
@NoArgsConstructor
public class PostCommentLikeId implements Serializable {

    @Column(name = "comment_id", nullable = false)
    private Long commentId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    public PostCommentLikeId(Long commentId, Long userId) {
        this.commentId = commentId;
        this.userId = userId;
    }

    @Override
    public boolean equals(Object o) {
        return o instanceof PostCommentLikeId k && Objects.equals(commentId, k.commentId) && Objects.equals(userId, k.userId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(commentId, userId);
    }
}
