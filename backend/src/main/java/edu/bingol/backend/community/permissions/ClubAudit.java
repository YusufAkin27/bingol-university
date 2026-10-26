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

/** Kulup denetim kaydi satiri (kim kime ne yapti). Kullanici id'leri bilerek FK degildir: kayit kullanicidan uzun yasar. */
@Entity
@Table(name = "club_audit")
@Getter
@Setter
public class ClubAudit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long communityId;

    private Long actorId;

    private Long targetUserId;

    @Column(nullable = false, length = 40)
    private String action;

    @Column(length = 500)
    private String detail;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
