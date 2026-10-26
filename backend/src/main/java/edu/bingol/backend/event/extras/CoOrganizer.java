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

/** Etkinlik ortak organizatoru (olusturanla ayni yonetim yetkisi; ortak eklemeyi yalniz sahip yapar). */
@Entity
@Table(name = "event_co_organizer")
@Getter
@Setter
public class CoOrganizer {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long eventId;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Long addedBy;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
