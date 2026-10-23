package edu.bingol.backend.community;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "community_member", uniqueConstraints = @UniqueConstraint(columnNames = {"community_id", "user_id"}))
@Getter
@Setter
public class CommunityMember {

    public enum Role {
        MEMBER, MODERATOR, OWNER;

        /** MODERATOR veya OWNER mu. */
        public boolean atLeastModerator() {
            return this != MEMBER;
        }
    }

    public enum Status { ACTIVE, PENDING, BANNED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long communityId;

    @Column(nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Role role = Role.MEMBER;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.ACTIVE;

    @Column(nullable = false)
    private Instant joinedAt = Instant.now();

    public CommunityMember() {}

    public CommunityMember(Long communityId, Long userId, Role role, Status status) {
        this.communityId = communityId;
        this.userId = userId;
        this.role = role;
        this.status = status;
    }

    public boolean isActive() {
        return status == Status.ACTIVE;
    }
}
