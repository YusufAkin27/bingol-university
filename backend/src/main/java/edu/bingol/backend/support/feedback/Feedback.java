package edu.bingol.backend.support.feedback;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class Feedback {

    public enum Category { BUG, SUGGESTION, COMPLAINT, PRAISE, OTHER }

    public enum Status { NEW, IN_REVIEW, PLANNED, DONE, REJECTED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Category category;

    @Column(nullable = false, length = 120)
    private String subject;

    @Column(nullable = false, length = 2000)
    private String message;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.NEW;

    @Column(length = 32)
    private String appVersion;

    @Column(length = 16)
    private String platform;

    @Column(length = 1000)
    private String adminResponse;

    private Instant respondedAt;

    /** Yalnizca SUGGESTION: yonetici herkese acik oneri panosuna alir. */
    @Column(name = "is_public", nullable = false)
    private boolean publicVisible;

    @Column(nullable = false)
    private int voteCount;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
