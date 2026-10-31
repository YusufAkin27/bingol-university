package edu.bingol.backend.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.CopyOnWriteArraySet;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;

/**
 * T-074 (A2-11): {@code @Scheduled} isleri, WebSocket'in {@code messageBrokerTaskScheduler} bean'i varken de
 * {@code sched-*} havuzunda kosar (eskiden iki is parcacikli MessageBroker-* havuzunu paylasiyordu).
 */
class SchedulingConfigTest {

    static final CopyOnWriteArraySet<String> THREADS = new CopyOnWriteArraySet<>();
    static final CountDownLatch RAN = new CountDownLatch(2);

    @Configuration
    @EnableScheduling
    static class Ctx {
        /** WebSocket yapilandirmasinin varsayilan zamanlayicisini taklit eder (eski davranisin nedeni). */
        @Bean(name = "messageBrokerTaskScheduler")
        ThreadPoolTaskScheduler messageBrokerTaskScheduler() {
            ThreadPoolTaskScheduler s = new ThreadPoolTaskScheduler();
            s.setPoolSize(2);
            s.setThreadNamePrefix("MessageBroker-");
            s.setDaemon(true);
            return s;
        }

        @Bean
        SchedulingConfig schedulingConfig() {
            return new SchedulingConfig(8);
        }

        @Bean
        Job job() {
            return new Job();
        }
    }

    static class Job {
        @Scheduled(fixedRate = 20)
        void tick() {
            THREADS.add(Thread.currentThread().getName());
            RAN.countDown();
        }
    }

    @Test
    void scheduledJobsRunOnDedicatedSchedPool() throws Exception {
        try (AnnotationConfigApplicationContext ctx = new AnnotationConfigApplicationContext(Ctx.class)) {
            assertThat(RAN.await(10, TimeUnit.SECONDS)).isTrue();
            SchedulingConfig cfg = ctx.getBean(SchedulingConfig.class);
            assertThat(cfg.poolSize()).isEqualTo(8);
            assertThat(cfg.threadNamePrefix()).isEqualTo("sched-");
        }
        assertThat(THREADS).isNotEmpty().allMatch(n -> n.startsWith("sched-"));
    }
}
