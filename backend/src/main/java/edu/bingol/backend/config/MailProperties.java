package edu.bingol.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.mail.*` ayarlari. enabled=false iken e-postalar gonderilmez, kuyruk isleyicisi icerigi log'a yazar
 * (yalnizca gelistirme).
 *
 * @param queuePollMs kuyruk isleyicisinin calisma araligi (ms)
 * @param maxAttempts bu kadar basarisiz denemeden sonra e-posta DEAD olur
 * @param batchSize   bir turda alinan en fazla e-posta
 * @param allowLogOnly prod profilinde enabled=false ile acilisa izin verir (kodlar yalnizca log'a yazilir);
 *                    bilincli kapali ortamlar icindir, varsayilan false
 */
@ConfigurationProperties("app.mail")
public record MailProperties(
        @DefaultValue("false") boolean enabled,
        @DefaultValue("no-reply@bingol.edu.tr") String from,
        @DefaultValue("BÜ Kampüs") String fromName,
        @DefaultValue("5000") long queuePollMs,
        @DefaultValue("5") int maxAttempts,
        @DefaultValue("20") int batchSize,
        @DefaultValue("false") boolean allowLogOnly) {
}
