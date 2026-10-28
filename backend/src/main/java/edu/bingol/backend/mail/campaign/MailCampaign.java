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

/** Toplu/secili e-posta kampanyasi. Alici e-posta metni tutulmaz; yalniz kullanici kimligi (KVKK). */
@Entity
@Table(name = "mail_campaign")
@Getter
@Setter
public class MailCampaign {

    public enum Status { DRAFT, SCHEDULED, SENDING, PAUSED, DONE, CANCELLED, FAILED }

    public enum AudienceType { ALL, FILTER, USERS, EMAILS }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(nullable = false)
    private Long templateId;

    @Column(nullable = false)
    private int templateVersion;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private Status status = Status.DRAFT;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 12)
    private AudienceType audienceType;

    /** FILTER: filtre JSON'u; USERS/EMAILS: virgullu kullanici kimlikleri. */
    @Column(columnDefinition = "TEXT")
    private String audienceValue;

    /** EMAILS/USERS hedefinde eslesmeyen (kayitli kullanici olmayan) girdi sayisi. */
    @Column(nullable = false)
    private int unmatchedCount;

    @Column(nullable = false)
    private int targetCount;

    private Instant scheduledAt;
    private Instant resolvedAt;
    private Instant startedAt;
    private Instant finishedAt;

    private Long createdBy;

    @Column(length = 64)
    private String requestKey;

    @Column(length = 300)
    private String error;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();
}
