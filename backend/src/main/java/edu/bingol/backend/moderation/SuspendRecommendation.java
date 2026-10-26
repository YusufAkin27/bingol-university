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

/** Tekrarlayan ihlal nedeniyle yoneticiye "askiya al" onerisi. Kullanici basina en fazla bir ACIK kayit. */
@Entity
@Getter
@Setter
public class SuspendRecommendation {

    public enum Status { OPEN, ACCEPTED, DISMISSED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private int strikeCount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.OPEN;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Long decidedBy;

    private Instant decidedAt;
}
