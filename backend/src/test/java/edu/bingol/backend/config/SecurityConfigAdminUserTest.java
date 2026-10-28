package edu.bingol.backend.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import org.junit.jupiter.api.Test;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/** ADMIN_PASSWORD verilmeyen (dev/test) acilista yonetici Basic kullanicisi uretilebilmeli (bcrypt 72 bayt siniri). */
class SecurityConfigAdminUserTest {

    private final SecurityConfig config = new SecurityConfig();

    @Test
    void bosParolaAcilisiCokertmezVeRastgeleParolaUretir() {
        BCryptPasswordEncoder enc = new BCryptPasswordEncoder(4);
        assertThatCode(() -> config.adminUser(enc, "admin", "")).doesNotThrowAnyException();
        UserDetailsService uds = config.adminUser(enc, "admin", "");
        UserDetails u = uds.loadUserByUsername("admin");
        assertThat(u.getAuthorities()).extracting(Object::toString).contains("ROLE_ADMIN");
        assertThat(enc.matches("", u.getPassword())).isFalse();
    }

    @Test
    void verilenParolaGecerli() {
        BCryptPasswordEncoder enc = new BCryptPasswordEncoder(4);
        UserDetails u = config.adminUser(enc, "admin", "Sifre-12345678").loadUserByUsername("admin");
        assertThat(enc.matches("Sifre-12345678", u.getPassword())).isTrue();
    }
}
