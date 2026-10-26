package edu.bingol.backend.config;

import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

/**
 * Tarayici tabanli yonetim paneli icin CORS: yalnizca /api/** ve /files/**. Kimlik Bearer basligindadir,
 * cerez yoktur (allowCredentials=false). Izin verilen kokenler `app.cors.allowed-origins` ile verilir.
 */
@Configuration
public class CorsConfig {

    @Bean
    CorsConfigurationSource corsConfigurationSource(CorsProperties props) {
        return source(props.origins());
    }

    static UrlBasedCorsConfigurationSource source(List<String> origins) {
        CorsConfiguration c = new CorsConfiguration();
        if (origins.contains("*")) {
            c.setAllowedOriginPatterns(List.of("*"));
        } else {
            c.setAllowedOrigins(origins);
        }
        c.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        c.setAllowedHeaders(List.of("Authorization", "Content-Type", "Accept-Language"));
        // Panel dosya adini (CSV), ETag'i, sayfalama imlecini, kirpilma bayragini ve Retry-After'i okuyabilsin
        c.setExposedHeaders(List.of("Content-Disposition", "ETag", "X-Next-Cursor", "X-Truncated", "Retry-After"));
        c.setAllowCredentials(false);
        c.setMaxAge(3600L);
        UrlBasedCorsConfigurationSource src = new UrlBasedCorsConfigurationSource();
        src.registerCorsConfiguration("/api/**", c);
        src.registerCorsConfiguration("/files/**", c);
        return src;
    }
}
