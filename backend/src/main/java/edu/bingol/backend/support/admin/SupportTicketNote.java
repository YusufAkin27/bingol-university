package edu.bingol.backend.support.admin;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Destek talebine IC NOT (P12). Musteriye GORUNMEZ: support_message'tan ayri tablodur; kullanici, herkese acik
 * durum sorgusu ve KVKK disa aktarimi bu tabloyu hic okumaz. Yalniz /api/admin/support uclari okur.
 */
@Entity
@Getter
@Setter
public class SupportTicketNote {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long ticketId;

    /** Yazan yonetici (Basic auth ise null). */
    private Long authorId;

    @Column(nullable = false, length = 2000)
    private String text;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
