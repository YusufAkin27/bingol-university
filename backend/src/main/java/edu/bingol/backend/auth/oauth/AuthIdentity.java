package edu.bingol.backend.auth.oauth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Hesaba bagli harici kimlik (Google/Apple). Eslesme anahtari (provider, subject)'tir; e-posta YALNIZ bilgidir ve
 * hesap eslestirmesinde tek basina kullanilmaz (otomatik birlestirme yok). Hesap silinince satir silinir (KVKK).
 */
@Entity
@Table(name = "auth_identity", uniqueConstraints = {
        @UniqueConstraint(name = "au1450_auth_identity_prov_sub_uq", columnNames = {"provider", "subject"}),
        @UniqueConstraint(name = "au1450_auth_identity_user_prov_uq", columnNames = {"user_id", "provider"})})
@Getter
@Setter
public class AuthIdentity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private OAuthProvider provider;

    @Column(nullable = false, length = 255)
    private String subject;

    @Column(length = 254)
    private String email;

    @Column(nullable = false)
    private boolean emailIsPrivate;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Instant lastLoginAt;
}
