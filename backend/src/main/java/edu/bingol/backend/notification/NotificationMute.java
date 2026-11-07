package edu.bingol.backend.notification;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import lombok.AllArgsConstructor;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Kullanicinin sessize aldigi kulup/etkinlik (V1630). */
@Entity
@Table(name = "notification_mute")
@IdClass(NotificationMute.Key.class)
@Getter
@Setter
public class NotificationMute {

    public static final String COMMUNITY = "COMMUNITY";
    public static final String EVENT = "EVENT";

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Id
    @Column(name = "target_type", length = 12)
    private String targetType;

    @Id
    @Column(name = "target_id")
    private Long targetId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    public NotificationMute() {}

    public NotificationMute(Long userId, String targetType, Long targetId) {
        this.userId = userId;
        this.targetType = targetType;
        this.targetId = targetId;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @EqualsAndHashCode
    public static class Key implements Serializable {
        private Long userId;
        private String targetType;
        private Long targetId;
    }
}
