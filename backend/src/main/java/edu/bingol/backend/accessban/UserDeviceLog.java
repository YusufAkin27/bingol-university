package edu.bingol.backend.accessban;

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

/** Kullanicinin gorulen cihaz (HMAC ozeti) + IP kaydi. 90 gun sonra silinir (KVKK). */
@Entity
@Table(name = "user_device_log", uniqueConstraints = @UniqueConstraint(name = "ban280_udl_unique",
        columnNames = {"user_id", "device_hash", "ip"}))
@Getter
@Setter
public class UserDeviceLog {

    /** Cihaz basligi gelmediginde device_hash yerine yazilan isaret. */
    public static final String NO_DEVICE = "-";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false, length = 64)
    private String deviceHash;

    @Column(nullable = false, length = 8)
    private String platform = "UNKNOWN";

    @Column(length = 32)
    private String appVersion;

    @Column(nullable = false, length = 45)
    private String ip;

    @Column(nullable = false)
    private short ipFamily;

    @Column(nullable = false)
    private Instant firstSeenAt = Instant.now();

    @Column(nullable = false)
    private Instant lastSeenAt = Instant.now();

    @Column(nullable = false, length = 10)
    private String lastEvent;

    @Column(nullable = false)
    private int seenCount = 1;
}
