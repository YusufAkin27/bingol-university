package edu.bingol.backend.academician;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/** Derse kayitli ogrenci (V1902); (course_id, student_id) tekil. */
@Entity
@Table(name = "ac_enrollment",
        uniqueConstraints = @UniqueConstraint(name = "ak1900_enroll_uq", columnNames = {"courseId", "studentId"}))
@Getter
@Setter
public class AcEnrollment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long courseId;

    @Column(nullable = false)
    private Long studentId;

    @Column(nullable = false)
    private Instant addedAt = Instant.now();

    /** Devamsizlik uyari duzeyi (0/1/2): ayni duzey iki kez bildirilmez; duzeltmede sessizce dusurulur. */
    @Column(nullable = false)
    private short warnedLevel;
}
