package edu.bingol.backend.event;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Kullanici/topluluk etkinligi (siteden gelen resmi ETKINLIK haberlerinden ayri). */
@Entity
@Table(name = "user_event")
@Getter
@Setter
public class UserEvent {

    /** PENDING_REVIEW: admin onayi bekler; CANCELLED: silindi/iptal; HIDDEN: rapor sonucu gizlendi. */
    public enum Status { PENDING_REVIEW, ACTIVE, REJECTED, CANCELLED, HIDDEN }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 150)
    private String title;

    @Column(length = 2000)
    private String description;

    @Column(nullable = false)
    private Instant startsAt;

    @Column(nullable = false)
    private Instant endsAt;

    @Column(length = 200)
    private String location;

    @Column(length = 300)
    private String coverUrl;

    /** Bos = sinirsiz. */
    private Integer capacity;

    /** GOING sayisi; yalnizca kosullu UPDATE'lerle (EventRepository) degisir. */
    @Column(nullable = false)
    private int goingCount;

    /** true: yeni RSVP/basvuru kabul edilmez; etkinlik gorunur kalir, mevcut RSVP'ler etkilenmez. */
    @Column(nullable = false)
    private boolean registrationClosed;

    private Long communityId;

    @Column(nullable = false)
    private Long createdBy;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.PENDING_REVIEW;

    @Column(length = 300)
    private String reviewNote;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
