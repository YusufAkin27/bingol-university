package edu.bingol.backend.mail.campaign;

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

/** Yonetici e-posta sablonunun ust kaydi; icerik {@link MailCustomTemplateVersion} satirlarindadir (surumlu). */
@Entity
@Table(name = "mail_template_custom")
@Getter
@Setter
public class MailCustomTemplate {

    public enum Status { DRAFT, PUBLISHED, ARCHIVED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(length = 500)
    private String description;

    /** Simdilik yalnizca ANNOUNCEMENT (duyuru; bastirma/abonelik tercihine tabidir). */
    @Column(nullable = false, length = 16)
    private String category = "ANNOUNCEMENT";

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Status status = Status.DRAFT;

    @Column(nullable = false)
    private int currentVersion = 1;

    private Long createdBy;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
