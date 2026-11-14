package edu.bingol.backend.academician;

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

/** Kayitli olmayan ogrencinin tarama istegi (V1903); (session_id, student_id) tekil. */
@Entity
@Table(name = "ac_scan_request",
        uniqueConstraints = @UniqueConstraint(name = "ak1900_scanreq_uq", columnNames = {"sessionId", "studentId"}))
@Getter
@Setter
public class AcScanRequest {

    public enum Status { PENDING, ACCEPTED, DISMISSED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long sessionId;

    @Column(nullable = false)
    private Long studentId;

    @Column(nullable = false)
    private Instant scannedAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Status status = Status.PENDING;

    private Instant decidedAt;

    private Long decidedBy;
}
