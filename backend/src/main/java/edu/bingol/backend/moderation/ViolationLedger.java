package edu.bingol.backend.moderation;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Ihlal defteri satiri (T-058, V990): silinen hesabin e-posta OZETI (HMAC-SHA256; ham adres yok) + devredilecek strike
 * sayisi + askiya alinmis mi. Yalniz ozet ve sayi tutulur; {@code expiresAt} sonrasi gecelik silinir.
 */
@Entity
@Table(name = "violation_ledger")
@Getter
@Setter
public class ViolationLedger {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 64)
    private String emailDigest;

    @Column(nullable = false)
    private int strikeCount;

    @Column(nullable = false)
    private boolean banned;

    @Column(nullable = false)
    private Instant recordedAt = Instant.now();

    @Column(nullable = false)
    private Instant expiresAt;
}
