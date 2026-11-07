package edu.bingol.backend.notification;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class Device {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false, unique = true, length = 500)
    private String fcmToken;

    @Column(nullable = false, length = 16)
    private String platform;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    /** Her kayitta yenilenir; kullanici basina cihaz siniri asilinca en eskiler silinir. */
    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    @Column(length = 32)
    private String appVersion;

    @Column(length = 16)
    private String locale;

    /** Explicit native renderer capability; older apps keep standard FCM alerts. */
    @Column(nullable = false)
    private boolean richNotifications;

    /** Uygulama her acilista kaydi yeniler; 60 gun gorulmeyen token'lar zamanlanmis isle silinir. */
    @Column(nullable = false)
    private Instant lastSeenAt = Instant.now();

    /**
     * Kaydin yapildigi oturum (access JWT `sid`; yoksa null). "Cihazlarim"dan o cihazdan cikista yalniz bu oturumun
     * push kaydi silinir; diger cihazlarin kayitlari kalir.
     */
    @Column(length = 32)
    private String sessionId;
}
