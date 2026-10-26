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
}
