package edu.bingol.backend.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** `jwt.*` ayarlari. */
@ConfigurationProperties("jwt")
public record JwtProperties(String secret, long accessTtlMinutes, long refreshTtlDays) {
}
