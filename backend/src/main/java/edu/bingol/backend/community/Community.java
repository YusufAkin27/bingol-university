package edu.bingol.backend.community;

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

@Entity
@Table(name = "community")
@Getter
@Setter
public class Community {

    public enum JoinPolicy { OPEN, APPROVAL }

    public enum Visibility { PUBLIC, PRIVATE }

    /** PENDING_REVIEW: admin onayi bekler; HIDDEN: rapor sonucu gizlendi. */
    public enum Status { PENDING_REVIEW, ACTIVE, REJECTED, HIDDEN }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 80)
    private String name;

    @Column(nullable = false, unique = true, length = 100)
    private String slug;

    @Column(length = 1000)
    private String description;

    @Column(length = 40)
    private String category;

    @Column(length = 300)
    private String coverUrl;

    /** Kulup logosu (T15): kapakla ayni gorsel hatti, ayri alan. */
    @Column(length = 300)
    private String logoUrl;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private JoinPolicy joinPolicy = JoinPolicy.OPEN;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Visibility visibility = Visibility.PUBLIC;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.PENDING_REVIEW;

    @Column(nullable = false)
    private Long ownerId;

    @Column(length = 300)
    private String reviewNote;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
