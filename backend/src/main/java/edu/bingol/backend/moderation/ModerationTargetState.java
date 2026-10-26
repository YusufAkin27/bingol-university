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

/** Moderasyon nedeniyle gizlenmis hedef (otomatik esik veya yonetici karari). Satir yoksa gizli degildir. */
@Entity
@Getter
@Setter
public class ModerationTargetState {

    public enum HiddenBy { AUTO, ADMIN }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private ReportTargetType targetType;

    @Column(nullable = false)
    private Long targetId;

    @Enumerated(EnumType.STRING)
    @Column(length = 8)
    private HiddenBy hiddenBy;

    private Instant hiddenAt;

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
