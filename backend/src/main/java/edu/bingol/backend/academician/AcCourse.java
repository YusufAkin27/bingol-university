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
import lombok.Getter;
import lombok.Setter;

/** Akademisyenin dersi (V1901). department = hedef kitle (toplu kayit bu bolumun ogrencilerini ceker). */
@Entity
@Table(name = "ac_course")
@Getter
@Setter
public class AcCourse {

    public enum Status { ACTIVE, ARCHIVED }

    public enum LimitType { COUNT, PERCENT }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long ownerId;

    @Column(length = 30)
    private String code;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(nullable = false, length = 40)
    private String term;

    @Column(length = 160)
    private String faculty;

    @Column(nullable = false, length = 160)
    private String department;

    @Column(length = 8)
    private String grade;

    @Enumerated(EnumType.STRING)
    @Column(length = 8)
    private LimitType absenceLimitType;

    private Short absenceLimitValue;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.ACTIVE;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
