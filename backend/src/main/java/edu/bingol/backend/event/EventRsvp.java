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

@Entity
@Table(name = "event_rsvp", uniqueConstraints = @UniqueConstraint(columnNames = {"event_id", "user_id"}))
@Getter
@Setter
public class EventRsvp {

    public enum Status { GOING, INTERESTED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long eventId;

    @Column(nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status;

    /** Hatirlatma isaretleri: ayni hatirlatma ikinci kez gitmez. */
    private boolean remindedDay;

    private boolean remindedHour;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    public EventRsvp() {}

    public EventRsvp(Long eventId, Long userId, Status status) {
        this.eventId = eventId;
        this.userId = userId;
        this.status = status;
    }
}
