package edu.bingol.backend.community.permissions;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Davet kodu: yalnizca SHA-256 ozeti saklanir; kod olusturulurken bir kez gosterilir. */
@Entity
@Table(name = "club_invite")
@Getter
@Setter
public class ClubInvite {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long communityId;

    @Column(nullable = false, length = 64)
    private String codeHash;

    /** Kodun son 3 karakteri (listede ayirt etmek icin). */
    @Column(nullable = false, length = 8)
    private String codeHint;

    @Column(nullable = false)
    private Long createdBy;

    /** null = sinirsiz kullanim. */
    private Integer maxUses;

    @Column(nullable = false)
    private int usedCount;

    @Column(nullable = false)
    private Instant expiresAt;

    @Column(nullable = false)
    private boolean revoked;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
