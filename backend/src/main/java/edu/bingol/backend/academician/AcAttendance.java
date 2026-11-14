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

/** Yoklama kaydi (V1903); (session_id, student_id) tekil. */
@Entity
@Table(name = "ac_attendance",
        uniqueConstraints = @UniqueConstraint(name = "ak1900_att_uq", columnNames = {"sessionId", "studentId"}))
@Getter
@Setter
public class AcAttendance {

    public enum Method { QR, MANUAL }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long sessionId;

    @Column(nullable = false)
    private Long studentId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 8)
    private Method method;

    @Column(nullable = false)
    private Instant markedAt = Instant.now();

    private Long markedBy;

    /** Ayrildi, v1'de kullanilmaz. */
    @Column(length = 64)
    private String deviceHash;

    /** Hoca kaydi kaldirdiysa zaman (yumusak silme): devamsiz sayilir, ogrenci ayni oturumda tekrar tarayamaz. */
    private Instant revokedAt;

    private Long revokedBy;

    /** Izinli/mazeretli: o oturum ogrencinin kendi sayimina girmez (ne var ne yok). */
    @Column(nullable = false)
    private boolean excused;

    public boolean isRevoked() {
        return revokedAt != null;
    }
}
