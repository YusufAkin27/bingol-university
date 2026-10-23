package edu.bingol.backend.legal;

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

/** Kullanicinin bir sozlesme surumunu kabul ettigine dair kalici kayit (ispat). */
@Entity
@Getter
@Setter
public class LegalAcceptance {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private LegalType docType;

    @Column(nullable = false)
    private int version;

    @Column(nullable = false)
    private Instant acceptedAt = Instant.now();
}
