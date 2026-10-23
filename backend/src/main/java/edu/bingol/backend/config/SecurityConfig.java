package edu.bingol.backend.config;

import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import java.util.UUID;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
public class SecurityConfig {

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /** /api/admin/** icin tek yonetici (Basic auth). Sifre verilmezse rastgele uretilir ve log'a yazilir. */
    @Bean
    UserDetailsService adminUser(PasswordEncoder encoder,
                                 @Value("${spring.security.user.name}") String name,
                                 @Value("${spring.security.user.password:}") String password) {
        String effective = password;
        if (effective.isBlank()) {
            effective = UUID.randomUUID().toString();
            LoggerFactory.getLogger(SecurityConfig.class)
                    .warn("ADMIN_PASSWORD verilmedi; gecici yonetici sifresi: {}", effective);
        }
        return new InMemoryUserDetailsManager(
                User.withUsername(name).password(encoder.encode(effective)).roles("ADMIN").build());
    }

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http, JwtService jwt, StringRedisTemplate redis) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(a -> a
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .requestMatchers("/api/auth/me").authenticated()
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/news", "/api/news/**", "/api/menu", "/api/menu/**", "/api/status").permitAll()
                .requestMatchers("/api/hello", "/actuator/health", "/files/**", "/error").permitAll()
                .anyRequest().authenticated())
            // Yonetim uclari (/api/admin/**) icin Basic auth (spring.security.user.*) korunur.
            .httpBasic(Customizer.withDefaults())
            .addFilterBefore(new JwtAuthFilter(jwt, redis), UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}
