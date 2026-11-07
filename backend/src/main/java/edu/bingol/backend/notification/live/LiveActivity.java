package edu.bingol.backend.notification.live;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Kullanicinin baslattigi bir iOS Canli Etkinlik'in sunucu kaydi (guncelleme jetonu dahil). */
@Entity
@Table(name = "live_activity")
@Getter
@Setter
public class LiveActivity {

    public enum Kind { EVENT, EXAM }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "activity_id", nullable = false, length = 64)
    private String activityId;

    @Column(nullable = false, length = 8)
    @jakarta.persistence.Enumerated(jakarta.persistence.EnumType.STRING)
    private Kind kind;

    @Column(name = "ref_id", nullable = false)
    private Long refId;

    @Column(name = "push_token", length = 400)
    private String pushToken;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "ended_at")
    private Instant endedAt;
}
