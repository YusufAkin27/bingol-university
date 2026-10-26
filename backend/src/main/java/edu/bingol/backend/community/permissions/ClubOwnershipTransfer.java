package edu.bingol.backend.community.permissions;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Iki asamali sahiplik devri: sahip teklif eder, hedef uye onaylarsa gerceklesir (geri alinamaz). */
@Entity
@Table(name = "club_ownership_transfer")
@Getter
@Setter
public class ClubOwnershipTransfer {

    public enum Status { PENDING, ACCEPTED, DECLINED, CANCELLED, EXPIRED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long communityId;

    @Column(nullable = false)
    private Long fromUserId;

    @Column(nullable = false)
    private Long toUserId;

    /** true ise eski sahip ADMIN olarak kalir, false ise kulupten ayrilir. */
    @Column(nullable = false)
    private boolean keepAsAdmin = true;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.PENDING;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant expiresAt;

    private Instant decidedAt;
}
