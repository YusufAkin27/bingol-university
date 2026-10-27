package edu.bingol.backend.post.like;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** post_like bilesik anahtari (post_id, user_id). */
@Embeddable
@Getter
@NoArgsConstructor
public class PostLikeId implements Serializable {

    @Column(name = "post_id", nullable = false)
    private Long postId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    public PostLikeId(Long postId, Long userId) {
        this.postId = postId;
        this.userId = userId;
    }

    @Override
    public boolean equals(Object o) {
        return o instanceof PostLikeId k && Objects.equals(postId, k.postId) && Objects.equals(userId, k.userId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(postId, userId);
    }
}
