package edu.bingol.backend.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ApplicationContext;
import org.springframework.scheduling.annotation.ScheduledAnnotationBeanPostProcessor;

/**
 * Test baglaminda {@code @Scheduled} islemesi KAPALI olmali (src/test/resources/application.properties:
 * {@code app.scheduling.enabled=false}). Aksi halde her onbellekteki baglam ~50 isi test sonuna kadar kosturur:
 * Redis olmadigi icin her tur hata yigini + baglanti denemesi, ortak H2 uzerinde hayalet sorgular.
 */
@SpringBootTest
class SchedulingDisabledInTestContextTest {

    @Autowired
    ApplicationContext ctx;

    @Test
    void scheduledAnnotationProcessingIsOff() {
        assertThat(ctx.getBeanNamesForType(ScheduledAnnotationBeanPostProcessor.class)).isEmpty();
    }
}
