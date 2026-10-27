package edu.bingol.backend.accessban;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Engellenen erisim denemesi (90 gun). Yazim {@link AccessBanHits} uzerinden toplu yapilir. */
@Entity
@Getter
@Setter
public class BlockedAttemptLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long banId;

    @Column(nullable = false, length = 12)
    private String kind;

    @Column(length = 45)
    private String ip;

    @Column(length = 64)
    private String deviceHash;

    private Long userId;

    @Column(length = 120)
    private String path;

    @Column(nullable = false)
    private Instant attemptedAt = Instant.now();
}
