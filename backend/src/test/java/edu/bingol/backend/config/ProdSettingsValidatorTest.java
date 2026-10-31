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
                .withProperty("spring.mail.properties.mail.smtp.starttls.required", "true")
                .withProperty("app.mail.unsubscribe-base-url", "https://kampus.bingol.edu.tr")
                .withProperty("app.fcm.credentials-file", "/run/secrets/fcm.json")
                .withProperty("BACKUP_REMOTE", "s3crypt:bu-yedek")
                .withProperty("app.admin.emails", "a@bingol.edu.tr,b@bingol.edu.tr")
                // T-149/T-150: Redis parolasi ve DB rol ayrimi (bingol_app = yalniz DML, bingol_owner = Flyway)
                .withProperty("spring.data.redis.password", "r4nd0m-redis-pass-9f3a2c71")
                .withProperty("spring.datasource.username", "bingol_app")
                .withProperty("spring.flyway.user", "bingol_owner");
    }

    @Test
    void blankRedisPasswordWarnsByDefaultAndFailsWhenRequired() {
        var warn = ProdSettingsValidator.validate(valid().withProperty("spring.data.redis.password", ""));
        assertTrue(warn.errors().isEmpty(), warn.errors().toString());
        assertTrue(warn.warnings().stream().anyMatch(w -> w.contains("REDIS_PASSWORD")), warn.warnings().toString());

        var req = ProdSettingsValidator.validate(valid().withProperty("spring.data.redis.password", "")
                .withProperty("app.security.require-redis-password", "true"));
        assertTrue(req.errors().stream().anyMatch(e -> e.contains("REDIS_PASSWORD")), req.errors().toString());
    }

    @Test
    void weakOrPlaceholderRedisPasswordIsRejectedAndValueNeverLogged() {
        var shortPw = ProdSettingsValidator.validate(valid().withProperty("spring.data.redis.password", "abc123"));
        assertTrue(shortPw.errors().stream().anyMatch(e -> e.contains("REDIS_PASSWORD")));
        var ph = ProdSettingsValidator.validate(valid().withProperty("spring.data.redis.password", "change-me-change-me-change-me"));
        assertTrue(ph.errors().stream().anyMatch(e -> e.contains("REDIS_PASSWORD")));
        assertFalse(ph.errors().toString().contains("change-me-change-me"), "parola degeri hata metnine yazilmamali");
        assertFalse(ProdSettingsValidator.validate(valid()).errors().toString().contains("r4nd0m-redis-pass"));
    }

    @Test
    void sameDatabaseAccountForAppAndFlywayWarnsByDefaultAndFailsWhenRequired() {
        var same = ProdSettingsValidator.validate(valid().withProperty("spring.flyway.user", "bingol_app"));
        assertTrue(same.errors().isEmpty(), same.errors().toString());
        assertTrue(same.warnings().stream().anyMatch(w -> w.contains("ayni PostgreSQL hesabini")), same.warnings().toString());

        var unset = ProdSettingsValidator.validate(valid().withProperty("spring.flyway.user", ""));
        assertTrue(unset.warnings().stream().anyMatch(w -> w.contains("ayni PostgreSQL hesabini")));

        var req = ProdSettingsValidator.validate(valid().withProperty("spring.flyway.user", "bingol_app")
                .withProperty("app.db.require-role-split", "true"));
        assertTrue(req.errors().stream().anyMatch(e -> e.contains("ayni PostgreSQL hesabini")), req.errors().toString());
        assertFalse(ProdSettingsValidator.validate(valid()).warnings().stream().anyMatch(w -> w.contains("ayni PostgreSQL")));
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
    void mailAndFcmOffOnlyWarnWhenLogOnlyAllowed() {
        var env = valid().withProperty("app.mail.enabled", "false").withProperty("app.fcm.credentials-file", "")
                .withProperty("app.mail.allow-log-only", "true");
        var r = ProdSettingsValidator.validate(env);
        assertTrue(r.errors().isEmpty());
        assertTrue(r.warnings().size() >= 2);
    }

    @Test
    void fcmJsonCredentialsCountAsConfigured() {
        var withJson = valid().withProperty("app.fcm.credentials-file", "")
                .withProperty("app.fcm.credentials-json", "e30=");
        assertTrue(ProdSettingsValidator.validate(withJson).warnings().isEmpty());
        var withEnv = valid().withProperty("app.fcm.credentials-file", "").withProperty("FCM_CREDENTIALS_JSON", "e30=");
        assertTrue(ProdSettingsValidator.validate(withEnv).warnings().isEmpty());
        var none = valid().withProperty("app.fcm.credentials-file", "");
        assertTrue(ProdSettingsValidator.validate(none).warnings().stream().anyMatch(w -> w.contains("FCM")));
    }

    @Test
    void mailOffIsAnErrorInProdWithoutExplicitFlag() {
        var r = ProdSettingsValidator.validate(valid().withProperty("app.mail.enabled", "false"));
        assertTrue(r.errors().stream().anyMatch(e -> e.contains("MAIL_ENABLED")));
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

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.ValueSource(strings = {
            "en-az-32-karakterlik-rastgele-bir-anahtar-yazin",
            "YER_TUTUCU_JWT_SIRRI_EN_AZ_32_KARAKTER",
            "change-me-to-a-long-random-secret-value-123456",
            "ReplaceMe-ChangeMe-0123456789-abcdefghijkl"})
    void exampleEnvPlaceholderJwtSecretsAreRejected(String secret) {
        var r = ProdSettingsValidator.validate(valid().withProperty("jwt.secret", secret));
        assertTrue(r.errors().stream().anyMatch(e -> e.contains("JWT_SECRET")), r.errors().toString());
    }

    @Test
    void lowDiversityJwtSecretIsRejected() {
        var r = ProdSettingsValidator.validate(valid().withProperty("jwt.secret", "ababababababababababababababababab"));
        assertTrue(r.errors().stream().anyMatch(e -> e.contains("JWT_SECRET")));
    }

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.ValueSource(strings = {
            "degistir", "YER_TUTUCU_YONETICI_SIFRESI", "change-me-please-123", "short-pw"})
    void placeholderOrShortAdminPasswordIsAnErrorWhenBasicIsEnabled(String pw) {
        var r = ProdSettingsValidator.validate(valid().withProperty("spring.security.user.password", pw));
        assertTrue(r.errors().stream().anyMatch(e -> e.contains("ADMIN_PASSWORD")), r.errors().toString());
    }

    @Test
    void adminPasswordIsNotRequiredWhenBasicAuthIsDisabled() {
        var r = ProdSettingsValidator.validate(valid().withProperty("app.security.admin-basic.enabled", "false")
                .withProperty("spring.security.user.password", ""));
        assertTrue(r.errors().isEmpty(), r.errors().toString());
    }

    @Test
    void placeholderDbPasswordAndCryptoKeysAreRejected() {
        var r = ProdSettingsValidator.validate(valid().withProperty("spring.datasource.password", "degistir")
                .withProperty("app.crypto.master-keys", "k1:YER_TUTUCU_BASE64_32_BAYT"));
        assertTrue(r.errors().stream().anyMatch(e -> e.contains("DB_PASSWORD")), r.errors().toString());
        assertTrue(r.errors().stream().anyMatch(e -> e.contains("CRYPTO_MASTER_KEYS")), r.errors().toString());
        assertFalse(r.errors().toString().contains("YER_TUTUCU_BASE64"));
    }

    @Test
    void realCryptoKeyIsAccepted() {
        var r = ProdSettingsValidator.validate(valid().withProperty("app.crypto.master-keys",
                "k1:q3Zr8mT1vJw0bN5xYc2LdF7sHkP9aUeGiOtR4yVn6Xs="));
        assertTrue(r.errors().isEmpty(), r.errors().toString());
    }

    // ---- W1-J (T-136 / T-153 / K-31): isletme uyarilari - hata DEGIL, acilisi engellemez ----

    @Test
    void emptyBackupRemoteWarnsButDoesNotFail() {
        var r = ProdSettingsValidator.validate(valid().withProperty("BACKUP_REMOTE", ""));
        assertTrue(r.errors().isEmpty(), r.errors().toString());
        assertTrue(r.warnings().stream().anyMatch(w -> w.contains("BACKUP_REMOTE")), r.warnings().toString());
        // ayar hic yokken de uyarir; tam ayarli ortamda uyari yoktur
        assertTrue(ProdSettingsValidator.validate(new MockEnvironment()).warnings().stream()
                .anyMatch(w -> w.contains("BACKUP_REMOTE")));
        var ok = ProdSettingsValidator.validate(valid());
        assertFalse(ok.warnings().stream().anyMatch(w -> w.contains("BACKUP_REMOTE")), ok.warnings().toString());
    }

    @Test
    void fewerThanTwoAdminEmailsWarn() {
        for (String v : new String[] {"", "  ", "a@bingol.edu.tr", "a@bingol.edu.tr, A@bingol.edu.tr ,", ",,"}) {
            var r = ProdSettingsValidator.validate(valid().withProperty("app.admin.emails", v));
            assertTrue(r.errors().isEmpty(), r.errors().toString());
            assertTrue(r.warnings().stream().anyMatch(w -> w.contains("ADMIN_EMAILS")), "deger: '" + v + "' " + r.warnings());
        }
        var two = ProdSettingsValidator.validate(valid().withProperty("app.admin.emails", "a@x.edu.tr, b@x.edu.tr"));
        assertFalse(two.warnings().stream().anyMatch(w -> w.contains("ADMIN_EMAILS")), two.warnings().toString());
    }

    @Test
    void sentryDsnWarnsOnlyWhenSet() {
        var on = ProdSettingsValidator.validate(valid().withProperty("sentry.dsn", "https://k@o1.ingest.sentry.io/1"));
        assertTrue(on.errors().isEmpty());
        assertTrue(on.warnings().stream().anyMatch(w -> w.contains("SENTRY_DSN")), on.warnings().toString());
        assertFalse(on.warnings().toString().contains("ingest.sentry.io"), "DSN degeri uyariya yazilmamali");
        var off = ProdSettingsValidator.validate(valid());
        assertFalse(off.warnings().stream().anyMatch(w -> w.contains("SENTRY_DSN")));
    }

    /** T-065 (A8-20): DSN AB (Frankfurt) bolgesinde degilse yurt disi aktarim uyarisi; AB bolgesinde yok. */
    @Test
    void sentryDsnOutsideEuRegionWarnsAboutTransfer() {
        var us = ProdSettingsValidator.validate(valid().withProperty("sentry.dsn", "https://k@o1.ingest.sentry.io/1"));
        assertTrue(us.warnings().stream().anyMatch(w -> w.contains("AB (Frankfurt)")), us.warnings().toString());
        var eu = ProdSettingsValidator.validate(valid().withProperty("sentry.dsn", "https://k@o1.ingest.de.sentry.io/1"));
        assertFalse(eu.warnings().stream().anyMatch(w -> w.contains("AB (Frankfurt)")), eu.warnings().toString());
        assertTrue(eu.errors().isEmpty());
    }
}
