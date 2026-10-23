package edu.bingol.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** `app.sync.*` ayarlari. */
@ConfigurationProperties("app.sync")
public record SyncProperties(boolean initialFill) {
}
