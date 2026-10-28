package edu.bingol.backend.moderation.admin;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Yonetilebilir karar nedeni sablonu (P11). Kullaniciya gosterilen metin tr/en/ar; bos en/ar Turkceye duser. */
@Entity
@Getter
@Setter
public class ModerationReasonTemplate {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 16)
    private String kind = "DECISION";

    @Column(nullable = false, length = 32)
    private String code;

    @Column(nullable = false, length = 300)
    private String textTr;

    @Column(length = 300)
    private String textEn;

    @Column(length = 300)
    private String textAr;

    @Column(nullable = false)
    private boolean active = true;

    @Column(nullable = false)
    private int sortOrder;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
