package edu.bingol.backend.profile.privacy;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "profile_privacy")
@Getter
@Setter
public class ProfilePrivacy {

    @Id
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Audience avatarAudience = Audience.EVERYONE;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Audience bioAudience = Audience.EVERYONE;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Audience departmentAudience = Audience.EVERYONE;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Audience facultyAudience = Audience.EVERYONE;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Audience classYearAudience = Audience.EVERYONE;

    /**
     * Cevrimici/son gorulme (T-025, V930). Varsayilan SHARED_CONTEXT (guvenli); ONLY_ME durumu hic gostermez.
     * Kullanici arayuzu/ucu (PrivacyService/PrivacyDtos) W2-D ile eklenecek.
     */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Audience presenceAudience = Audience.SHARED_CONTEXT;

    /**
     * "Rehberden bulunabilirim" (T-061, V995): acik onay, varsayilan KAPALI. Kapaliyken rehber eslestirmede ne
     * bulunur ne de rehber eslestirme kullanilabilir (karsilikli). Ucu: ContactMatchController.
     */
    private boolean contactsDiscoverable;

    /** Moderasyon avatari gizledi (USER_AVATAR raporu). */
    private boolean avatarHidden;

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    public static ProfilePrivacy defaults(Long userId) {
        ProfilePrivacy p = new ProfilePrivacy();
        p.userId = userId;
        return p;
    }
}
