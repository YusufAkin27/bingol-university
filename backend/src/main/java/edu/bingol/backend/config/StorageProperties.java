package edu.bingol.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** `app.storage.*`: yuklenen dosyalarin kaydedildigi dizin (Docker'da volume). */
@ConfigurationProperties("app.storage")
public record StorageProperties(String dir) {
}
