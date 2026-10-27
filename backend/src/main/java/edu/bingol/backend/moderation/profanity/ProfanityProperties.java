package edu.bingol.backend.moderation.profanity;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * `app.moderation.profanity.*`
 * <ul>
 *   <li>enabled: filtre acik mi (varsayilan true)</li>
 *   <li>mode: BLOCK (422 ile reddet) | FLAG (engelleme yok, yalnizca istatistige FLAG olarak yazilir)</li>
 *   <li>cache-ttl-seconds: yonetici kelime degisikligi diger ornekte en gec bu surede gorunur</li>
 * </ul>
 */
@ConfigurationProperties("app.moderation.profanity")
public record ProfanityProperties(
        @DefaultValue("true") boolean enabled,
        @DefaultValue("BLOCK") Mode mode,
        @DefaultValue("30") int cacheTtlSeconds) {

    public enum Mode { BLOCK, FLAG }
}
