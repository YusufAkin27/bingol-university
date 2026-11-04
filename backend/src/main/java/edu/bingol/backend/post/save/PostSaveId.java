package edu.bingol.backend.post.save;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** post_save bilesik anahtari (user_id, post_id). */
@Embeddable
@Getter
@NoArgsConstructor
public class PostSaveId implements Serializable {

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "post_id", nullable = false)
    private Long postId;

    public PostSaveId(Long userId, Long postId) {
        this.userId = userId;
        this.postId = postId;
    }

    @Override
    public boolean equals(Object o) {
        return o instanceof PostSaveId k && Objects.equals(userId, k.userId) && Objects.equals(postId, k.postId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId, postId);
    }
}
