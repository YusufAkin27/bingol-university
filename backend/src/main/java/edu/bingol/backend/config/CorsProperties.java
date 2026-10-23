package edu.bingol.backend.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/** `app.cors.allowed-origins`: tarayicidan (yonetim paneli) API'ye izin verilen kokenler (virgullu liste). Bos ise CORS kapali. */
@ConfigurationProperties("app.cors")
public record CorsProperties(List<String> allowedOrigins) {

    public List<String> origins() {
        return allowedOrigins == null ? List.of() : allowedOrigins.stream().map(String::trim).filter(s -> !s.isEmpty()).toList();
    }
}
