package edu.bingol.backend.forum.topic;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.io.Serializable;
import java.util.Objects;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** forum_bookmark bilesik anahtari (user_id, target_type, target_id). */
@Embeddable
@Getter
@NoArgsConstructor
public class ForumBookmarkId implements Serializable {

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "target_type", nullable = false, length = 10)
    private String targetType;

    @Column(name = "target_id", nullable = false)
    private Long targetId;

    public ForumBookmarkId(Long userId, String targetType, Long targetId) {
        this.userId = userId;
        this.targetType = targetType;
        this.targetId = targetId;
    }

    @Override
    public boolean equals(Object o) {
        return o instanceof ForumBookmarkId k && Objects.equals(userId, k.userId)
                && Objects.equals(targetType, k.targetType) && Objects.equals(targetId, k.targetId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId, targetType, targetId);
    }
}
