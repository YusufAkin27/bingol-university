package edu.bingol.backend.user;

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
@Table(name = "app_user")
@Getter
@Setter
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 254)
    private String email;

    @Column(nullable = false, length = 100)
    private String passwordHash;

    @Column(nullable = false, length = 80)
    private String displayName;

    private boolean emailVerified;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private Role role = Role.USER;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private UserStatus status = UserStatus.ACTIVE;

    @Column(length = 120)
    private String department;

    private Short classYear;

    @Column(length = 300)
    private String bio;

    @Column(length = 300)
    private String avatarUrl;

    private boolean showEmail;

    /** tr | en | ar: bildirim ve e-posta dili. */
    @Column(nullable = false, length = 2)
    private String language = "tr";

    @Column(length = 300)
    private String suspendedReason;

    private Instant deletedAt;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    public boolean isActive() {
        return status == UserStatus.ACTIVE;
    }
}
