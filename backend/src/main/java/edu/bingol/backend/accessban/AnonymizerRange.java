package edu.bingol.backend.accessban;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Yoneticinin yukledigi anonimlestirici (Tor cikis, VPN, veri merkezi) aralik. */
@Entity
@Table(name = "ban280_anonymizer_range")
@Getter
@Setter
public class AnonymizerRange {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 50)
    private String cidr;

    @Column(length = 60)
    private String source;

    @Column(nullable = false)
    private Instant addedAt = Instant.now();
}
