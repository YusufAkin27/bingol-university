package edu.bingol.backend.notification.campaign;

import edu.bingol.backend.notification.NotificationType;
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

/** Yoneticinin mobil uygulamadan olusturdugu push kampanyasi (anlik veya zamanlanmis). */
@Entity
@Getter
@Setter
public class PushCampaign {

    public enum AudienceType { ALL, DEPARTMENT, CLASS_YEAR, USERS, ADMINS, SELF }

    public enum TargetType { NONE, NEWS, EVENT, COMMUNITY, TICKET, URL }

    public enum Status { SCHEDULED, SENDING, SENT, CANCELLED, FAILED }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long createdBy;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private NotificationType type = NotificationType.ANNOUNCEMENT;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private AudienceType audienceType;

    /** DEPARTMENT: bolum adi, CLASS_YEAR: sayi, USERS: virgulle ayrilmis kullanici id'leri. */
    @Column(length = 2000)
    private String audienceValue;

    @Column(nullable = false, length = 100)
    private String titleTr;

    @Column(nullable = false, length = 300)
    private String bodyTr;

    @Column(length = 100)
    private String titleEn;

    @Column(length = 300)
    private String bodyEn;

    @Column(length = 100)
    private String titleAr;

    @Column(length = 300)
    private String bodyAr;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private TargetType targetType = TargetType.NONE;

    @Column(length = 500)
    private String targetValue;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Status status = Status.SCHEDULED;

    @Column(nullable = false)
    private Instant scheduledAt;

    private Instant startedAt;

    private Instant finishedAt;

    private Integer recipientCount;

    @Column(length = 500)
    private String error;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
