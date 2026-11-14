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

/** Ders duyurusu (V1904): yalniz sabit turler (alan kurallari NoticeRules). */
@Entity
@Table(name = "ac_notice")
@Getter
@Setter
public class AcNotice {

    public enum Type { LESSON_STARTED, ATTENDANCE_STARTED, EXAM, ASSIGNMENT, MATERIAL, LESSON_CANCELLED, ROOM_CHANGED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long courseId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private Type type;

    @Column(length = 120)
    private String title;

    @Column(length = 1000)
    private String note;

    private Instant eventAt;

    private Long createdBy;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
