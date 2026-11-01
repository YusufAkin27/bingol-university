package edu.bingol.backend.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.scheduling.annotation.ScheduledAnnotationBeanPostProcessor;

/**
 * {@code app.scheduling.enabled}: varsayilan (ayarsiz) ACIK = uretim davranisi degismez; {@code false} {@code @Scheduled}
 * islemesini hic kurmaz (test baglamlarinda ~50 zamanlayici isinin calismasini onler).
 */
class SchedulingEnabledConfigTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withUserConfiguration(SchedulingEnabledConfig.class);

    @Test
    void enabledByDefault() {
        runner.run(ctx -> assertThat(ctx).hasSingleBean(ScheduledAnnotationBeanPostProcessor.class));
    }

    @Test
    void enabledWhenTrue() {
        runner.withPropertyValues("app.scheduling.enabled=true")
                .run(ctx -> assertThat(ctx).hasSingleBean(ScheduledAnnotationBeanPostProcessor.class));
    }

    @Test
    void disabledWhenFalse() {
        runner.withPropertyValues("app.scheduling.enabled=false")
                .run(ctx -> assertThat(ctx).doesNotHaveBean(ScheduledAnnotationBeanPostProcessor.class));
    }
}
