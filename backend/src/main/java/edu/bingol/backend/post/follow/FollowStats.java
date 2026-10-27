package edu.bingol.backend.post.follow;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Denormalize takipci/takip sayaci (atomik SQL ile guncellenir). */
@Entity
@Table(name = "user_follow_stats")
@Getter
@Setter
@NoArgsConstructor
public class FollowStats {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Column(name = "follower_count", nullable = false)
    private int followerCount;

    @Column(name = "following_count", nullable = false)
    private int followingCount;
}
