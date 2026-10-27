package edu.bingol.backend.post.social;

import jakarta.persistence.AttributeOverride;
import jakarta.persistence.AttributeOverrides;
import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Kaydedilen gonderi (yalniz kaydeden gorur). id: a = user_id, b = post_id. */
@Entity
@Table(name = "post_save")
@Getter
@Setter
@NoArgsConstructor
public class PostSave {

    @EmbeddedId
    @AttributeOverrides({@AttributeOverride(name = "a", column = @Column(name = "user_id")),
            @AttributeOverride(name = "b", column = @Column(name = "post_id"))})
    private PairId id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public PostSave(Long userId, Long postId) {
        this.id = new PairId(userId, postId);
    }
}
