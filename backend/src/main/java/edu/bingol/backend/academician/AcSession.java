package edu.bingol.backend.academician;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import lombok.Getter;
import lombok.Setter;

/** Yoklama oturumu (V1903). OPEN ve simdi < expiresAt ise canli; sure tembel dolar. */
@Entity
@Table(name = "ac_session")
@Getter
@Setter
public class AcSession {

    public enum Status { OPEN, CLOSED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long courseId;

    private Long slotId;

    @Column(nullable = false)
    private LocalDate lessonDate;

    @Column(nullable = false)
    private Instant openedAt;

    @Column(nullable = false)
    private Instant expiresAt;

    private Instant closedAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private Status status = Status.OPEN;

    public boolean isLive(Instant now) {
        return status == Status.OPEN && now.isBefore(expiresAt);
    }
}
