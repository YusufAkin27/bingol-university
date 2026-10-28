package edu.bingol.backend.admin.rbac;

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

/** Iki kisi onayli yonetici profili degisikligi onerisi (24 saat gecerli). */
@Entity
@Table(name = "admin_profile_change")
@Getter
@Setter
public class AdminProfileChange {

    public enum Status { PENDING, APPROVED, REJECTED, EXPIRED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long targetUserId;

    @Enumerated(EnumType.STRING)
    @Column(length = 16)
    private AdminProfile fromProfile;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private AdminProfile toProfile;

    @Column(nullable = false, length = 300)
    private String reason;

    @Column(nullable = false)
    private Long proposedBy;

    @Column(nullable = false)
    private Instant proposedAt;

    @Column(nullable = false)
    private Instant expiresAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Status status = Status.PENDING;

    private Long decidedBy;

    private Instant decidedAt;

    @Column(length = 300)
    private String decisionNote;
}
