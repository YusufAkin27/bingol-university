package edu.bingol.backend.moderation.profanity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Engellenen (veya FLAG ile isaretlenen) deneme. Kelime SAKLANMAZ. */
@Entity
@Getter
@Setter
@NoArgsConstructor
public class ProfanityHitLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 40)
    private String field;

    @Column(nullable = false, length = 24)
    private String entity;

    private Long userId;

    @Column(nullable = false, length = 8)
    private String action = "BLOCK";

    @Column(name = "at", nullable = false)
    private Instant at = Instant.now();
}
