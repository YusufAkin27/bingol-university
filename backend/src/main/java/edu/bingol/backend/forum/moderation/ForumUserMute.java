package edu.bingol.backend.forum.moderation;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Tek yonlu forum sessize alma: {@code userId}, {@code mutedUserId}'nin forum iceriklerini kendi gorunumunden gizler. */
@Entity
@Table(name = "forum_user_mute")
@IdClass(ForumUserMute.Key.class)
@Getter
@Setter
@NoArgsConstructor
public class ForumUserMute {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Id
    @Column(name = "muted_user_id")
    private Long mutedUserId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public ForumUserMute(Long userId, Long mutedUserId) {
        this.userId = userId;
        this.mutedUserId = mutedUserId;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @EqualsAndHashCode
    public static class Key implements Serializable {
        private Long userId;
        private Long mutedUserId;
    }
}
