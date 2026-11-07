package edu.bingol.backend.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

/**
 * FIX-P10: yeni eklenen altyapi anahtarlarinin VARSAYILANI bugunku davranisi korumali (test classpath'inde
 * src/test/resources/application.properties main'inkini golgeledigi icin ana dosya dogrudan okunur).
 * Etkinlestirme deploy-zamani kararidir (docs/DEPLOY.md); varsayilan degisirse bu test bilincli guncellenir.
 */
class MainPropertiesDefaultsTest {

    private static final Path MAIN = Path.of("src/main/resources/application.properties");
    private static Properties props;

    @BeforeAll
    static void load() throws IOException {
        props = new Properties();
        try (var in = Files.newBufferedReader(MAIN, StandardCharsets.UTF_8)) {
            props.load(in);
        }
    }

    /** {@code ${ENV:varsayilan}} bicimindeki degerin varsayilan kismi. */
    private static String defaultOf(String key) {
        String v = props.getProperty(key);
        assertThat(v).as(key).isNotNull();
        int i = v.indexOf(':');
        assertThat(v).as(key).startsWith("${").endsWith("}");
        return v.substring(i + 1, v.length() - 1);
    }

    @Test
    void httpHistogramStaysOnAndSloEmptyByDefault() {
        assertThat(defaultOf("management.metrics.distribution.percentiles-histogram.http.server.requests")).isEqualTo("true");
        assertThat(defaultOf("management.metrics.distribution.slo.http.server.requests")).isEmpty();
    }

    @Test
    void redisPasswordAndLedgerOffByDefault() {
        assertThat(defaultOf("spring.data.redis.password")).isEmpty();
        assertThat(defaultOf("app.security.require-redis-password")).isEqualTo("false");
        assertThat(defaultOf("app.privacy.deletion-ledger-file")).isEmpty();
    }

    @Test
    void singleInstanceSchedulingOffByDefault() {
        assertThat(defaultOf("app.scheduling.single-instance")).isEqualTo("false");
    }

    @Test
    void schedulingSwitchIsNotExposedAsEnvVar() {
        // uretimde ENV ile tum zamanlayicilari kapatmak istenmez: anahtar main properties'te hic yok (ayarsiz = acik)
        assertThat(props.getProperty("app.scheduling.enabled")).isNull();
    }
}
