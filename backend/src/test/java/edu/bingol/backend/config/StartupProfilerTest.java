package edu.bingol.backend.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.metrics.buffering.BufferingApplicationStartup;
import org.springframework.core.metrics.StartupStep;

class StartupProfilerTest {

    @Test
    void disabledByDefault() {
        // STARTUP_PROFILE ayarsizken tampon acilmaz (uretim davranisi degismez)
        if (System.getenv("STARTUP_PROFILE") == null) {
            assertThat(StartupProfiler.enabled()).isFalse();
            assertThat(StartupProfiler.startupOrNull()).isNull();
        }
    }

    @Test
    void slowestStepsAreSortedAndTagged() throws Exception {
        BufferingApplicationStartup startup = new BufferingApplicationStartup(100);
        StartupStep fast = startup.start("spring.beans.instantiate").tag("beanName", "fastBean");
        fast.end();
        StartupStep slow = startup.start("spring.beans.instantiate").tag("beanName", "slowBean");
        Thread.sleep(40);
        slow.end();

        List<String> lines = StartupProfiler.slowest(startup.getBufferedTimeline(), 5);

        assertThat(lines).hasSize(2);
        assertThat(lines.get(0)).contains("slowBean").contains("spring.beans.instantiate");
        assertThat(lines.get(1)).contains("fastBean");
    }

    @Test
    void limitIsRespected() {
        BufferingApplicationStartup startup = new BufferingApplicationStartup(100);
        for (int i = 0; i < 10; i++) {
            startup.start("step" + i).end();
        }
        assertThat(StartupProfiler.slowest(startup.getBufferedTimeline(), 3)).hasSize(3);
    }
}
