package edu.bingol.backend.post.save;

import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Bir kullanicinin kaydettigi gonderi/reel (post_save, V1230). Yalniz sahibi gorur. */
@Entity
@Table(name = "post_save")
@Getter
@Setter
@NoArgsConstructor
public class PostSave {

    @EmbeddedId
    private PostSaveId id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public PostSave(Long userId, Long postId) {
        this.id = new PostSaveId(userId, postId);
    }
}
