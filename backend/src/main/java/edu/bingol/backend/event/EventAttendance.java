package edu.bingol.backend.event;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Yoklama kaydi; kim, ne zaman, hangi yontemle yazdi bilgisi tutulur. */
@Entity
@Table(name = "event_attendance", uniqueConstraints = @UniqueConstraint(columnNames = {"event_id", "user_id"}))
@Getter
@Setter
public class EventAttendance {

    public enum Method { QR, MANUAL }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long eventId;

    @Column(nullable = false)
    private Long userId;

    private boolean present;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private Method method;

    /** QR'da kullanicinin kendisi, elle yoklamada isaretleyen organizator. */
    @Column(nullable = false)
    private Long markedBy;

    @Column(nullable = false)
    private Instant markedAt = Instant.now();
}
