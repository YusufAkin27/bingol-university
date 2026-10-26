package edu.bingol.backend.event.extras;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Gonderilmis toplu duyuru kaydi (yalniz gunluk siniri saymak icin; metin tutulmaz). */
@Entity
@Table(name = "event_announcement")
@Getter
@Setter
public class EventAnnouncement {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long eventId;

    @Column(nullable = false)
    private Long senderId;

    @Column(nullable = false)
    private int recipients;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
