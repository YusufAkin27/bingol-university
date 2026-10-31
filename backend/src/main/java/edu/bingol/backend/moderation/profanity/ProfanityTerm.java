package edu.bingol.backend.moderation.profanity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Yonetici tarafindan eklenen ozel kelime (BLOCK = engelle, ALLOW = izin ver). */
@Entity
@Getter
@Setter
@NoArgsConstructor
public class ProfanityTerm {

    public enum Kind { BLOCK, ALLOW }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 80)
    private String term;

    @Column(nullable = false, length = 100)
    private String termNormalized;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private Kind kind;

    @Column(nullable = false, length = 4)
    private String lang = "ALL";

    /** Kategori (V992); varsayilan PROFANITY. */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private ProfanityCategory category = ProfanityCategory.PROFANITY;

    @Column(length = 200)
    private String note;

    private Long createdBy;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
