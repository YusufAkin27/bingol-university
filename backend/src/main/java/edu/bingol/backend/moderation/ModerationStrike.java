package edu.bingol.backend.moderation;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Kullanici basina cozulmus ihlal kaydi. Itiraz kabul edilirse revokedAt dolar ve sayilmaz. */
@Entity
@Getter
@Setter
public class ModerationStrike {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    private Long reportId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private ReportTargetType targetType;

    @Column(nullable = false)
    private Long targetId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private Report.Resolution resolution;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Instant revokedAt;

    /** Yonetici afi (P11): af eden yonetici (Basic auth ise null) ve sebep. Itiraz kabulunde bos kalir. */
    private Long forgivenBy;

    @Column(length = 300)
    private String forgivenReason;

    /** Ihlal defterinden devralindi (T-058): silinip ayni e-postayla yeniden kayit olan hesabin onceki ihlali. */
    @Column(nullable = false)
    private boolean inherited;
}
