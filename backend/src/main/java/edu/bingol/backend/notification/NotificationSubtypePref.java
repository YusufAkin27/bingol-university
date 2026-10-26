package edu.bingol.backend.notification;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.Setter;

/** Alt tur tercihi (satir yoksa acik sayilir). */
@Entity
@Getter
@Setter
@Table(name = "notification_subtype_pref",
        uniqueConstraints = @UniqueConstraint(name = "ntf73_subtype_pref_uq", columnNames = {"user_id", "subtype"}))
public class NotificationSubtypePref {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false, length = 32)
    private String subtype;

    @Column(nullable = false)
    private boolean enabled;
}
