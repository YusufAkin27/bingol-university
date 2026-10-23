package edu.bingol.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** `app.mail.*` ayarlari. enabled=false iken kodlar e-posta yerine log'a yazilir (yalnizca gelistirme). */
@ConfigurationProperties("app.mail")
public record MailProperties(boolean enabled, String from) {
}
