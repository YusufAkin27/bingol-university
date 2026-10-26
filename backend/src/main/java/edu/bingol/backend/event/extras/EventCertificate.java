package edu.bingol.backend.event.extras;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Katilim sertifikasi verisi (PDF yok); code tahmin edilemez dogrulama kodudur. */
@Entity
@Table(name = "event_certificate", uniqueConstraints = @UniqueConstraint(columnNames = {"event_id", "user_id"}))
@Getter
@Setter
public class EventCertificate {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long eventId;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false, length = 32, unique = true)
    private String code;

    /** Duzenlenme anindaki gorunen ad. */
    @Column(nullable = false, length = 100)
    private String holderName;

    @Column(nullable = false)
    private Instant issuedAt = Instant.now();
}
