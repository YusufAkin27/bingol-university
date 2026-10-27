package edu.bingol.backend.config;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.auth.*` ayarlari.
 *
 * @param pendingRegistrationTtl dogrulanmamis (bekleyen) kaydin Redis'te kalma suresi; sure dolunca kayit silinir
 *                               ve kullanici yeniden kayit olur. Yenilenmez (sinirsiz uzamaz).
 */
@ConfigurationProperties("app.auth")
public record AuthProperties(@DefaultValue("72h") Duration pendingRegistrationTtl) {
}
