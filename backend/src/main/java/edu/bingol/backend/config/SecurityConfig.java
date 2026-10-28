package edu.bingol.backend.config;

import edu.bingol.backend.admin.AuditAccessDeniedHandler;
import edu.bingol.backend.auth.jwt.JwtAuthFilter;
import edu.bingol.backend.auth.jwt.JwtService;
import java.util.UUID;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
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
import org.springframework.security.web.header.writers.DelegatingRequestMatcherHeaderWriter;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter.ReferrerPolicy;
import org.springframework.security.web.header.writers.StaticHeadersWriter;
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher;
import org.springframework.security.web.util.matcher.AndRequestMatcher;
import org.springframework.security.web.util.matcher.NegatedRequestMatcher;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfigurationSource;

@Configuration
public class SecurityConfig {

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * /api/admin/** icin tek yonetici (Basic auth; yalniz `app.security.admin-basic.enabled=true` iken kullanilir,
     * prod varsayilani KAPALI). Sifre verilmezse rastgele uretilir ve HICBIR YERE yazilmaz (Basic fiilen kullanilamaz;
     * yerelde ADMIN_PASSWORD verin). Sifre log'a yazilirsa log erisimi = tam yonetici yetkisi olurdu.
     */
    @Bean
    UserDetailsService adminUser(PasswordEncoder encoder,
                                 @Value("${spring.security.user.name:admin}") String name,
                                 @Value("${spring.security.user.password:}") String password) {
        String effective = password;
        if (effective.isBlank()) {
            effective = UUID.randomUUID() + "-" + UUID.randomUUID();
            LoggerFactory.getLogger(SecurityConfig.class)
                    .warn("ADMIN_PASSWORD verilmedi: yonetici Basic auth kullanilamaz (JWT ADMIN gecerlidir)");
        }
        return new InMemoryUserDetailsManager(
                User.withUsername(name).password(encoder.encode(effective)).roles("ADMIN").build());
    }

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http, JwtService jwt, StringRedisTemplate redis,
                                    @Qualifier("corsConfigurationSource") CorsConfigurationSource cors,
                                    AuditAccessDeniedHandler denied,
                                    edu.bingol.backend.common.ApiAuthenticationEntryPoint apiEntryPoint,
                                    edu.bingol.backend.common.RateLimiter limiter,
                                    edu.bingol.backend.common.ClientIp clientIp,
                                    org.springframework.core.env.Environment env,
                                    @Value("${app.security.admin-basic.enabled:true}") boolean adminBasic,
                                    @Value("${app.security.admin-basic.fail-closed:true}") boolean failClosed)
            throws Exception {
        // Basic kapaliyken /api/admin/** da kimliksiz isteklere {code,message} 401 doner (Basic zorlugu yok).
        org.springframework.security.web.util.matcher.RequestMatcher apiMatcher = adminBasic
                ? new AndRequestMatcher(PathPatternRequestMatcher.withDefaults().matcher("/api/**"),
                        new NegatedRequestMatcher(PathPatternRequestMatcher.withDefaults().matcher("/api/admin/**")))
                : PathPatternRequestMatcher.withDefaults().matcher("/api/**");
        http.csrf(AbstractHttpConfigurer::disable)
            // CORS yalnizca /api/** ve /files/** icin (CorsConfig); preflight (OPTIONS) kimlik dogrulamasindan once yanitlanir
            .cors(c -> c.configurationSource(cors))
            // Yetkisiz yonetici istekleri (403) denetim kaydina da yazilir
            // Kimliksiz 401 govdesi {code,message} olsun (mobil icin); yonetici Basic auth zorlugu (WWW-Authenticate) korunur.
            .exceptionHandling(e -> e.accessDeniedHandler(denied)
                    .defaultAuthenticationEntryPointFor(apiEntryPoint, apiMatcher))
            // Guvenlik basliklari. HSTS yalnizca HTTPS isteklerde yazilir (proxy arkasinda forward-headers ile).
            // CSP yalnizca API/dosya yanitlari icin kisitli; Swagger arayuzu (dev) betik yukleyebilsin diye haric.
            .headers(h -> h
                .contentTypeOptions(Customizer.withDefaults())
                .frameOptions(f -> f.deny())
                .httpStrictTransportSecurity(t -> t.includeSubDomains(true).maxAgeInSeconds(31536000))
                .referrerPolicy(r -> r.policy(ReferrerPolicy.NO_REFERRER))
                .addHeaderWriter(new DelegatingRequestMatcherHeaderWriter(
                        new NegatedRequestMatcher(new OrRequestMatcher(
                                PathPatternRequestMatcher.withDefaults().matcher("/swagger-ui/**"),
                                PathPatternRequestMatcher.withDefaults().matcher("/swagger-ui.html"))),
                        new StaticHeadersWriter("Content-Security-Policy",
                                "default-src 'none'; frame-ancestors 'none'; base-uri 'none'"))))
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(a -> a
                // T7: OpenAPI belgesi ve Swagger arayuzu yalnizca ADMIN (arayuz ayrica varsayilan kapali)
                .requestMatchers("/v3/api-docs", "/v3/api-docs/**", "/swagger-ui.html", "/swagger-ui/**").hasRole("ADMIN")
                // Actuator: yalnizca saglik denetimi herkese acik (orkestrator/proxy); digerleri ADMIN (prod'da zaten kapali)
                .requestMatchers("/actuator/health", "/actuator/health/**").permitAll()
                // Prometheus kazimasi: YALNIZ ayri yonetim portunda (MANAGEMENT_PORT, compose agi ici) herkese acik;
                // ana portta (8080) bu kural eslesmez ve /actuator/** ADMIN kalir.
                .requestMatchers(request -> managementPort(env) > 0 && request.getLocalPort() == managementPort(env)
                        && "/actuator/prometheus".equals(request.getRequestURI())).permitAll()
                .requestMatchers("/actuator/**").hasRole("ADMIN")
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .requestMatchers("/api/auth/me", "/api/auth/logout-all", "/api/auth/change-password","/api/legal/consents", "/api/legal/consents/**", "/api/legal/accept", "/api/legal/acceptance-status").authenticated()
                .requestMatchers(HttpMethod.GET, "/api/faq", "/api/legal", "/api/legal/*", "/api/legal/*/versions",
                        "/api/app/info", "/api/app/version", "/api/faculties", "/api/catalog/academic", "/api/catalog/departments").permitAll()
                .requestMatchers("/api/auth/**").permitAll()
                // T27: herkese acik destek talebi (hiz siniri + e-posta dogrulamasi servis katmaninda)
                .requestMatchers("/api/public/support/**").permitAll()
                // Mail teslim edilebilirligi: imzali jetonla abonelikten cikma (IP hiz siniri controller'da)
                .requestMatchers("/api/public/mail/unsubscribe").permitAll()
                // T14: katilim sertifikasi dogrulama herkese acik (kod tahmin edilemez, IP hiz siniri var)
                .requestMatchers(HttpMethod.GET, "/api/certificates/verify/*").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/news","/api/news/**", "/api/menu", "/api/menu/**", "/api/status").permitAll()
                .requestMatchers("/api/hello", "/actuator/health", "/files/**", "/error").permitAll()
                // WebSocket el sikismasi acik; kimlik STOMP CONNECT'te (JWT) zorunlu (bkz. messaging.ws.StompAuthInterceptor)
                .requestMatchers("/ws", "/ws/**").permitAll()
                .anyRequest().authenticated())
            .addFilterBefore(new JwtAuthFilter(jwt, redis), UsernamePasswordAuthenticationFilter.class);
        // Yonetim uclari (/api/admin/**) icin Basic auth (spring.security.user.*): yalniz aciksa (prod'da varsayilan
        // kapali; yalniz JWT ROLE_ADMIN). Aciksa basarisiz deneme sayaci + fail-closed kisitlayici onunde calisir.
        if (adminBasic) {
            http.httpBasic(Customizer.withDefaults())
                .addFilterBefore(new BasicAuthThrottleFilter(limiter, clientIp, redis, failClosed),
                        org.springframework.security.web.authentication.www.BasicAuthenticationFilter.class);
        }
        return http.build();
    }

    /** management.server.port (bos/yoksa 0 = ayri port yok). */
    static int managementPort(org.springframework.core.env.Environment env) {
        String v = env.getProperty("management.server.port");
        try {
            return v == null || v.isBlank() ? 0 : Integer.parseInt(v.trim());
        } catch (NumberFormatException e) {
            return 0;
        }
    }
}
