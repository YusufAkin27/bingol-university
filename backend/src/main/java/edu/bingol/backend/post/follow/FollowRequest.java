package edu.bingol.backend.post.follow;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Bekleyen takip isteği (V1020): yalnız gizli hesaplara. Okuma/yazma düz SQL ile (FollowRequestService); varlık
 * şemanın tek tanımı için (ddl-auto=validate, test şeması) vardır.
 */
@Entity
@Table(name = "follow_request", uniqueConstraints = @UniqueConstraint(name = "frq_pair_uq",
        columnNames = {"requester_id", "target_id"}))
@Getter
@Setter
@NoArgsConstructor
public class FollowRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "requester_id", nullable = false)
    private Long requesterId;

    @Column(name = "target_id", nullable = false)
    private Long targetId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();
}
