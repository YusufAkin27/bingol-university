package edu.bingol.backend.observability;

import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.binder.MeterBinder;
import io.micrometer.observation.ObservationRegistry;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.SchedulingConfigurer;

/**
 * Sistem gostergelerini Prometheus'a acar ve zamanlayici gozlemini garanti eder.
 *
 * <p>Metrikler (hepsi {@code SystemOverviewService.cached()} uzerinden, en cok 15 sn'de bir hesaplanir):
 * {@code bu_indicator_status{indicator}} (0 OK, 1 WARN, 2 CRIT, -1 UNKNOWN), {@code bu_indicator_value{indicator}}
 * (sayisal deger; sayisal degilse NaN), {@code bu_system_status} (genel). Mail kuyrugu icin eski
 * {@code bu_mail_outbox{status}} ve push sayaclari {@code config/ObservabilityMetrics} icinde kalir.
 */
@Configuration(proxyBeanMethods = false)
public class ObservabilityConfig {

    @Bean
    MeterBinder systemIndicatorMetrics(ObjectProvider<SystemOverviewService> service) {
        return registry -> {
            SystemOverviewService s = service.getIfAvailable();
            if (s == null) {
                return;
            }
            Gauge.builder("bu.system.status", s, o -> safeOverall(o)).description("Genel sistem durumu (0 OK, 1 WARN, 2 CRIT, -1 UNKNOWN)")
                    .register(registry);
            for (String key : SystemOverviewService.indicatorKeys()) {
                Gauge.builder("bu.indicator.status", s, o -> status(o, key)).tag("indicator", key)
                        .description("Gosterge durumu (0 OK, 1 WARN, 2 CRIT, -1 UNKNOWN)").register(registry);
                Gauge.builder("bu.indicator.value", s, o -> value(o, key)).tag("indicator", key)
                        .description("Gosterge sayisal degeri (birim gostergeye gore)").register(registry);
            }
        };
    }

    /** @Scheduled gorevlerinin gozlenmesi (JobMonitor) icin kayit defterini zamanlayiciya baglar. */
    @Bean
    SchedulingConfigurer observationSchedulingConfigurer(ObjectProvider<ObservationRegistry> registry) {
        return taskRegistrar -> {
            ObservationRegistry r = registry.getIfAvailable();
            if (r != null && taskRegistrar.getObservationRegistry() == null) {
                taskRegistrar.setObservationRegistry(r);
            }
        };
    }

    private static double safeOverall(SystemOverviewService s) {
        try {
            return s.cached().overall().metricValue();
        } catch (RuntimeException e) {
            return Double.NaN;
        }
    }

    private static double status(SystemOverviewService s, String key) {
        try {
            Indicator i = s.cached().indicators().get(key);
            return i == null ? Double.NaN : i.status().metricValue();
        } catch (RuntimeException e) {
            return Double.NaN;
        }
    }

    private static double value(SystemOverviewService s, String key) {
        try {
            Indicator i = s.cached().indicators().get(key);
            return i != null && i.value() instanceof Number n ? n.doubleValue() : Double.NaN;
        } catch (RuntimeException e) {
            return Double.NaN;
        }
    }
}
