package edu.bingol.backend.auth.session;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.Setter;

/**
 * Bir giris zincirinin (login + refresh rotasyonlari) oturum kaydi: "Cihazlarim" listesi ve tek cihazdan cikis.
 * {@code sid} access JWT'deki `sid` talebi ve refresh kaydindaki 4. alandir. Ham IP ve ham cihaz kimligi tutulmaz:
 * {@code ipMasked} kismen maskelidir, {@code deviceHash} ClientContexts HMAC ozetidir. {@code authTimeMs} refresh
 * zincirinin giris ani (RefreshTokenService aile kimligi).
 */
@Entity
@Table(name = "user_session")
@Getter
@Setter
public class UserSession {

    @Id
    @Column(length = 32)
    private String sid;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false, length = 8)
    private String client;

    @Column(length = 16)
    private String platform;

    @Column(length = 80)
    private String deviceName;

    @Column(length = 64)
    private String deviceHash;

    @Column(length = 32)
    private String appVersion;

    @Column(length = 64)
    private String ipMasked;

    @Column(nullable = false)
    private long authTimeMs;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant lastUsedAt = Instant.now();

    private Instant revokedAt;
}
