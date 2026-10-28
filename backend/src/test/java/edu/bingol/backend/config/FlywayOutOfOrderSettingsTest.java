package edu.bingol.backend.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;
import org.junit.jupiter.api.Test;

/**
 * Flyway out-of-order: dev icin acik (paralel kollar), uretim profilinde kapali. Test sinif yolundaki
 * application.properties main'dekinin yerine gectiginden ana dosyalar dogrudan dosya sisteminden okunur.
 */
class FlywayOutOfOrderSettingsTest {

    private static final Path MAIN = Paths.get("src/main/resources");

    private static Properties load(String name) throws IOException {
        Properties p = new Properties();
        try (InputStream in = Files.newInputStream(MAIN.resolve(name))) {
            p.load(in);
        }
        return p;
    }

    @Test
    void prodProfileDisablesOutOfOrder() throws IOException {
        assertThat(load("application-prod.properties").getProperty("spring.flyway.out-of-order"))
                .isEqualTo("false");
    }

    @Test
    void defaultProfileKeepsOutOfOrderForDev() throws IOException {
        assertThat(load("application.properties").getProperty("spring.flyway.out-of-order"))
                .isEqualTo("true");
    }
}
