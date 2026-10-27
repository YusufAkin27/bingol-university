package edu.bingol.backend.accessban;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Erisim engeli. kind: IP | CIDR | DEVICE | USER; banValue: IP/CIDR metni, cihaz HMAC ozeti ya da kullanici id. */
@Entity
@Getter
@Setter
public class AccessBan {

    public static final String IP = "IP";
    public static final String CIDR = "CIDR";
    public static final String DEVICE = "DEVICE";
    public static final String USER = "USER";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 8)
    private String kind;

    @Column(nullable = false, length = 80)
    private String banValue;

    @Column(length = 300)
    private String note;

    @Column(nullable = false, length = 16)
    private String reasonCode = "OTHER";

    private Long createdBy;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    /** null = suresiz. */
    private Instant expiresAt;

    @Column(nullable = false)
    private boolean active = true;

    @Column(nullable = false)
    private long hitCount;

    private Instant lastHitAt;

    public boolean liveAt(Instant now) {
        return active && (expiresAt == null || expiresAt.isAfter(now));
    }
}
