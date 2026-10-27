package edu.bingol.backend.notification.outbox;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Duration;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Gonderilecek tek bir (cihaz, mesaj) kaydi. Durum gecisleri bu sinifin metotlariyla yapilir. */
@Entity
@Table(name = "push_outbox")
@Getter
@Setter
public class PushOutbox {

    static final int MAX_ERROR_LENGTH = 300;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long userId;

    private Long deviceId;

    @Column(length = 64)
    private String fcmTokenHash;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String payloadJson;

    @Column(nullable = false)
    private short priority;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private PushOutboxStatus status = PushOutboxStatus.PENDING;

    @Column(nullable = false)
    private int attempts;

    @Column(nullable = false)
    private Instant nextAttemptAt = Instant.now();

    private Instant leaseUntil;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Instant sentAt;

    @Column(length = MAX_ERROR_LENGTH)
    private String lastError;

    @Column(length = 120)
    private String dedupeKey;

    public void markSent(Instant now) {
        status = PushOutboxStatus.SENT;
        sentAt = now;
        leaseUntil = null;
        lastError = null;
    }

    /** Gecici hata: sayaci artirir; limit asildiysa DEAD, degilse geri cekilmeyle yeniden planlar. */
    public void markFailed(String error, Instant now, int maxAttempts) {
        attempts++;
        leaseUntil = null;
        lastError = clip(error);
        if (attempts >= maxAttempts) {
            status = PushOutboxStatus.DEAD;
        } else {
            status = PushOutboxStatus.FAILED;
            nextAttemptAt = now.plus(PushOutboxBackoff.delay(attempts));
        }
    }

    /** Kalici hata ya da vazgecme (token gecersiz, cihaz silinmis, sure doldu): yeniden denenmez. */
    public void markDead(String reason) {
        status = PushOutboxStatus.DEAD;
        leaseUntil = null;
        lastError = clip(reason);
    }

    public Duration age(Instant now) {
        return Duration.between(createdAt, now);
    }

    private static String clip(String s) {
        return s == null ? null : s.substring(0, Math.min(s.length(), MAX_ERROR_LENGTH));
    }
}
