package edu.bingol.backend.auth.twofactor;

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

/**
 * 2FA guvenilen cihaz: kod dogrulanarak (ya da 2FA acilirken) tanitilmis cihaz. Ham cihaz kimligi tutulmaz;
 * {@code deviceHash} ClientContexts HMAC-SHA256 ozetidir. {@code label} yalniz platform/surumdur.
 */
@Entity
@Table(name = "two_factor_device", uniqueConstraints = @UniqueConstraint(name = "tf_device_user_hash_uq",
        columnNames = {"user_id", "device_hash"}))
@Getter
@Setter
public class TwoFactorDevice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false, length = 64)
    private String deviceHash;

    @Column(length = 80)
    private String label;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant lastUsedAt = Instant.now();
}
