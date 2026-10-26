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

@Entity
@Getter
@Setter
public class Report {

    public enum Status { OPEN, RESOLVED }

    public enum Resolution { DISMISS, HIDE, WARN, SUSPEND_USER }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long reporterId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private ReportTargetType targetType;

    @Column(nullable = false)
    private Long targetId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private ReportReason reason;

    @Column(length = 500)
    private String note;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.OPEN;

    @Enumerated(EnumType.STRING)
    @Column(length = 24)
    private Resolution resolution;

    private Long resolvedBy;

    /** Kuyruk onceligi: acik farkli raporlayici sayisi * 10 (+100 otomatik/yonetici gizlemesi varsa). */
    @Column(nullable = false)
    private int priority;

    /** Karar nedeni sablonu ({@link DecisionReason}); isteğe bagli. */
    @Column(length = 32)
    private String reasonCode;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Instant resolvedAt;
}
