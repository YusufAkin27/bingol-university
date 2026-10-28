package edu.bingol.backend.event;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Yonetici moderasyon gecmisi satiri (event_moderation_log). */
@Entity
@Table(name = "event_moderation_log")
@Getter
@Setter
public class EventModerationLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long eventId;

    /** NULL: Basic auth yoneticisi ya da rapor otomasyonu. */
    private Long adminId;

    @Column(nullable = false, length = 16)
    private String action;

    @Column(nullable = false, length = 16)
    private String fromStatus;

    @Column(nullable = false, length = 16)
    private String toStatus;

    @Column(length = 300)
    private String reason;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
