package edu.bingol.backend.mail;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.config.MailProperties;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.source.MapConfigurationPropertySource;

class MailPropertiesTest {

    @Test
    void defaultsApplyWhenNothingConfigured() {
        MailProperties p = new Binder(new MapConfigurationPropertySource(Map.of("app.mail.enabled", "false")))
                .bind("app.mail", MailProperties.class).get();

        assertThat(p.enabled()).isFalse();
        assertThat(p.from()).isEqualTo("no-reply@bingol.edu.tr");
        assertThat(p.fromName()).isEqualTo("BÜ Kampüs");
        assertThat(p.queuePollMs()).isEqualTo(5000);
        assertThat(p.maxAttempts()).isEqualTo(5);
        assertThat(p.batchSize()).isEqualTo(20);
    }

    @Test
    void configuredValuesOverrideDefaults() {
        MailProperties p = new Binder(new MapConfigurationPropertySource(Map.of(
                "app.mail.enabled", "true", "app.mail.max-attempts", "3", "app.mail.from-name", "Test")))
                .bind("app.mail", MailProperties.class).get();

        assertThat(p.enabled()).isTrue();
        assertThat(p.maxAttempts()).isEqualTo(3);
        assertThat(p.fromName()).isEqualTo("Test");
    }
}
