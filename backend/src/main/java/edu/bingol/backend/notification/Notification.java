package edu.bingol.backend.notification;

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
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private NotificationType type;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(length = 500)
    private String body;

    /** Yonlendirme icin kisa JSON, ornek {"newsId":"12"}. */
    @Column(length = 1000)
    private String data;

    @Column(length = 32)
    private String subtype;

    /** Ayni anahtarli okunmamis bildirimler tek satirda birlesir (ornek: "conv:42"). */
    @Column(length = 120)
    private String collapseKey;

    @Column(nullable = false)
    private int groupCount = 1;

    private Instant readAt;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();
}
