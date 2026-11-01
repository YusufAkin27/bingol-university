package edu.bingol.backend.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Bindable;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.micrometer.metrics.autoconfigure.MetricsProperties;
import org.springframework.core.env.PropertiesPropertySource;
import org.springframework.mock.env.MockEnvironment;

/**
 * Ana application.properties'teki {@code http.server.requests} kova ayarlari: varsayilan (ENV yok) histogram ACIK ve SLO
 * bos dizi olarak baglanir (bos deger Boot'ta hata vermemeli); ENV ile az kovali model secilebilir.
 * Test classpath'indeki application.properties main'inkini golgeledigi icin ana dosya dogrudan okunur.
 */
class HttpMetricsBindingTest {

    private static MetricsProperties bind(MockEnvironment env) throws IOException {
        Properties p = new Properties();
        try (var in = Files.newBufferedReader(Path.of("src/main/resources/application.properties"), StandardCharsets.UTF_8)) {
            p.load(in);
        }
        env.getPropertySources().addLast(new PropertiesPropertySource("main", p));
        return Binder.get(env).bind("management.metrics", Bindable.of(MetricsProperties.class)).get();
    }

    @Test
    void defaultKeepsHistogramAndEmptySlo() throws IOException {
        MetricsProperties props = bind(new MockEnvironment());

        assertThat(props.getDistribution().getPercentilesHistogram()).containsEntry("http.server.requests", true);
        assertThat(props.getDistribution().getSlo().get("http.server.requests")).isNullOrEmpty();
    }

    @Test
    void envSwitchesToSloBuckets() throws IOException {
        MockEnvironment env = new MockEnvironment()
                .withProperty("METRICS_HTTP_PERCENTILES_HISTOGRAM", "false")
                .withProperty("METRICS_HTTP_SLO", "50ms,100ms,250ms,500ms,1s,3s,10s");

        MetricsProperties props = bind(env);

        assertThat(props.getDistribution().getPercentilesHistogram()).containsEntry("http.server.requests", false);
        assertThat(props.getDistribution().getSlo().get("http.server.requests")).hasSize(7);
    }
}
