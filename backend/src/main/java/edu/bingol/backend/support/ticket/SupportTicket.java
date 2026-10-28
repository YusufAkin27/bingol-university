package edu.bingol.backend.support.ticket;

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

@Entity
@Getter
@Setter
public class SupportTicket {

    public enum Category { ACCOUNT, TECHNICAL, CONTENT, OTHER }

    /** OPEN: kullanici bekliyor, ANSWERED: personel yanitladi, CLOSED: kapali. */
    public enum Status { OPEN, ANSWERED, CLOSED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Herkese acik (hesapsiz) taleplerde null. */
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Category category;

    @Column(nullable = false, length = 120)
    private String subject;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.OPEN;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    private Instant closedAt;

    // --- P12: yonetici onceligi + atama (kullanici uclarinda gosterilmez) ---
    public enum Priority { LOW, NORMAL, HIGH, URGENT }

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private Priority priority = Priority.NORMAL;

    private Long assigneeId;

    // --- T27: herkese acik talep ---
    @Column(nullable = false)
    private boolean publicTicket;

    /** Dogrulanmamis herkese acik talepler yonetim listesinde gorunmez. */
    @Column(nullable = false)
    private boolean emailVerified = true;

    @Column(length = 254)
    private String contactEmail;

    @Column(length = 80)
    private String contactName;

    @Column(nullable = false, length = 2)
    private String lang = "tr";

    @Column(length = 64)
    private String codeHash;

    private Instant codeExpiresAt;

    @Column(nullable = false)
    private int codeAttempts;
}
