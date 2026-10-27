package edu.bingol.backend.post.like;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Bir kullanicinin bir gonderiyi begenisi. */
@Entity
@Table(name = "post_like")
@Getter
@Setter
@NoArgsConstructor
public class PostLike {

    @EmbeddedId
    private PostLikeId id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public PostLike(Long postId, Long userId) {
        this.id = new PostLikeId(postId, userId);
    }
}
