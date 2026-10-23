package edu.bingol.backend.moderation;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import java.io.Serializable;
import java.time.Instant;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@IdClass(UserBlock.Key.class)
@Getter
@Setter
@NoArgsConstructor
public class UserBlock {

    @Id
    private Long blockerId;

    @Id
    private Long blockedId;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    public UserBlock(Long blockerId, Long blockedId) {
        this.blockerId = blockerId;
        this.blockedId = blockedId;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @EqualsAndHashCode
    public static class Key implements Serializable {
        private Long blockerId;
        private Long blockedId;
    }
}
