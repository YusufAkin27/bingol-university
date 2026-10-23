package edu.bingol.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
            .authorizeHttpRequests(a -> a
                .requestMatchers(HttpMethod.GET, "/api/news", "/api/news/**", "/api/menu", "/api/menu/**", "/api/status").permitAll()
                .requestMatchers("/api/hello","/actuator/health", "/h2-console/**").permitAll()
                .anyRequest().authenticated())
            .headers(h -> h.frameOptions(f -> f.sameOrigin()))
            .httpBasic(Customizer.withDefaults());
        return http.build();
    }
}
