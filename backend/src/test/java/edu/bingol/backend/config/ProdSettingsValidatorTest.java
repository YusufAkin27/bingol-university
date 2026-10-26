package edu.bingol.backend.config;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

class ProdSettingsValidatorTest {

    private static MockEnvironment valid() {
        return new MockEnvironment()
                .withProperty("spring.datasource.password", "db-pass-123")
                .withProperty("jwt.secret", "a-very-random-secret-value-0123456789abcdef")
                .withProperty("spring.security.user.password", "admin-pass-1234567")
                .withProperty("app.cors.allowed-origins", "https://kampus.bingol.edu.tr")
                .withProperty("app.mail.enabled", "true")
                .withProperty("spring.mail.host", "smtp.example.com")
                .withProperty("app.fcm.credentials-file", "/run/secrets/fcm.json");
    }

    @Test
    void validEnvironmentHasNoErrorsOrWarnings() {
        var r = ProdSettingsValidator.validate(valid());
        assertTrue(r.errors().isEmpty(), r.errors().toString());
        assertTrue(r.warnings().isEmpty(), r.warnings().toString());
    }

    @Test
    void devJwtSecretAndShortSecretsAreRejected() {
        var dev = ProdSettingsValidator.validate(
                valid().withProperty("jwt.secret", "dev-only-secret-change-me-in-production-0123456789"));
        assertTrue(dev.errors().stream().anyMatch(e -> e.contains("JWT_SECRET")));
        var shortSecret = ProdSettingsValidator.validate(valid().withProperty("jwt.secret", "short"));
        assertTrue(shortSecret.errors().stream().anyMatch(e -> e.contains("JWT_SECRET")));
    }

    @Test
    void missingMandatorySettingsAreAllReported() {
        var r = ProdSettingsValidator.validate(new MockEnvironment());
        assertTrue(r.errors().size() >= 4, r.errors().toString());
        assertTrue(r.errors().stream().anyMatch(e -> e.contains("DB_PASSWORD")));
        assertTrue(r.errors().stream().anyMatch(e -> e.contains("ADMIN_PASSWORD")));
        assertTrue(r.errors().stream().anyMatch(e -> e.contains("CORS_ORIGINS")));
    }

    @Test
    void wildcardCorsAndDevDbPasswordAreRejected() {
        var r = ProdSettingsValidator.validate(valid()
                .withProperty("app.cors.allowed-origins", "*")
                .withProperty("spring.datasource.password", "bingol"));
        assertTrue(r.errors().stream().anyMatch(e -> e.contains("CORS_ORIGINS")));
        assertTrue(r.errors().stream().anyMatch(e -> e.contains("DB_PASSWORD")));
    }

    @Test
    void mailAndFcmOffOnlyWarn() {
        var env = valid().withProperty("app.mail.enabled", "false").withProperty("app.fcm.credentials-file", "");
        var r = ProdSettingsValidator.validate(env);
        assertTrue(r.errors().isEmpty());
        assertTrue(r.warnings().size() >= 2);
    }

    @Test
    void errorsNeverContainSecretValues() {
        var r = ProdSettingsValidator.validate(valid().withProperty("jwt.secret", "dev-only-SUPERSECRETVALUE-0123456789abcdef"));
        assertFalse(r.errors().toString().contains("SUPERSECRETVALUE"));
    }

    @Test
    void constructorFailsFastOnInvalidEnvironment() {
        assertThrows(IllegalStateException.class, () -> new ProdSettingsValidator(new MockEnvironment()));
    }
}
