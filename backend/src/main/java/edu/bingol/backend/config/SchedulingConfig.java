package edu.bingol.backend.config;

import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.SchedulingConfigurer;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;
import org.springframework.scheduling.config.ScheduledTaskRegistrar;

/**
 * T-074 (A2-11): {@code @Scheduled} isleri ozel, adli bir havuzda kosar.
 *
 * <p>{@code @EnableWebSocketMessageBroker} kendi {@code messageBrokerTaskScheduler} bean'ini tanimladigi icin Spring
 * Boot kendi zamanlayicisini olusturmaz ve 40'tan fazla {@code @Scheduled} is, boyutu CPU sayisi (2) olan WebSocket
 * broker havuzunu paylasirdi: iki uzun is (gece haber senkronu, bakim) posta/push/presence dongulerini aciktirirdi.
 * Burada ayri havuz ({@code sched-*}) acikca kaydedilir; WebSocket kalp atisi zaten kendi zamanlayicisini kullanir.
 * Havuz bean OLMADIGI icin ikinci bir {@code TaskScheduler} bean'i olusup WebSocket yapilandirmasini etkilemez.
 */
@Configuration(proxyBeanMethods = false)
public class SchedulingConfig implements SchedulingConfigurer {

    private final ThreadPoolTaskScheduler scheduler;
    private final int poolSize;

    public SchedulingConfig(@Value("${app.scheduling.pool-size:8}") int poolSize) {
        ThreadPoolTaskScheduler s = new ThreadPoolTaskScheduler();
        this.poolSize = Math.max(2, poolSize);
        s.setPoolSize(this.poolSize);
        s.setThreadNamePrefix("sched-");
        s.setDaemon(true);
        s.setRemoveOnCancelPolicy(true);
        s.setWaitForTasksToCompleteOnShutdown(false);
        s.initialize();
        this.scheduler = s;
    }

    @Override
    public void configureTasks(ScheduledTaskRegistrar taskRegistrar) {
        taskRegistrar.setScheduler(scheduler);
    }

    /** Test/teshis icin: havuz boyutu. */
    int poolSize() {
        return poolSize;
    }

    /** Test/teshis icin: is parcacigi adi oneki. */
    String threadNamePrefix() {
        return scheduler.getThreadNamePrefix();
    }

    @PreDestroy
    void shutdown() {
        scheduler.shutdown();
    }
}
