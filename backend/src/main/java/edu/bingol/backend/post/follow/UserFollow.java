package edu.bingol.backend.post.follow;

import edu.bingol.backend.post.social.PairId;
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

/** Takip iliskisi. id: a = follower_id (takip eden), b = followee_id (takip edilen). */
@Entity
@Table(name = "user_follow")
@Getter
@Setter
@NoArgsConstructor
public class UserFollow {

    @EmbeddedId
    @AttributeOverrides({@AttributeOverride(name = "a", column = @Column(name = "follower_id")),
            @AttributeOverride(name = "b", column = @Column(name = "followee_id"))})
    private PairId id;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public UserFollow(Long followerId, Long followeeId) {
        this.id = new PairId(followerId, followeeId);
    }
}
