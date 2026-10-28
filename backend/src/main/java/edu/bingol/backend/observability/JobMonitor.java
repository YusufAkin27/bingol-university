package edu.bingol.backend.observability;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.observation.Observation;
import io.micrometer.observation.ObservationHandler;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.scheduling.support.ScheduledTaskObservationContext;
import org.springframework.stereotype.Component;
import org.springframework.util.ClassUtils;

/**
 * Zamanlayici (@Scheduled) calismalarinin son basari/hata zamani ve hata sayaci. Spring'in zamanlayici gozlemini
 * dinler (is koduna dokunmaz); anahtar "SinifAdi.metot" (ornek {@code MailQueueWorker.poll}). Bellek ici: uygulama
 * yeniden baslayinca sifirlanir, ilk calismaya kadar gosterge UNKNOWN kalir.
 *
 * <p>Metrikler: {@code bu_scheduler_last_success_seconds{job}} (epoch sn), {@code bu_scheduler_errors_total{job}}.
 */
@Component
public class JobMonitor implements ObservationHandler<Observation.Context> {

    /** Bir gorevin ozeti. */
    public record Stat(Instant lastSuccess, Instant lastError, long runs, long errors) {
    }

    private final Map<String, Stat> stats = new ConcurrentHashMap<>();
    private final Map<String, Counter> counters = new ConcurrentHashMap<>();
    private final MeterRegistry registry;

    public JobMonitor(MeterRegistry registry) {
        this.registry = registry;
    }

    @Override
    public boolean supportsContext(Observation.Context context) {
        return context instanceof ScheduledTaskObservationContext;
    }

    @Override
    public void onStop(Observation.Context context) {
        if (!(context instanceof ScheduledTaskObservationContext ctx) || ctx.getTargetClass() == null
                || ctx.getMethod() == null) {
            return;
        }
        String job = ClassUtils.getUserClass(ctx.getTargetClass()).getSimpleName() + "." + ctx.getMethod().getName();
        if (ctx.getError() != null) {
            recordFailure(job, Instant.now());
        } else {
            recordSuccess(job, Instant.now());
        }
    }

    public void recordSuccess(String job, Instant at) {
        stats.merge(job, new Stat(at, null, 1, 0),
                (o, n) -> new Stat(at, o.lastError(), o.runs() + 1, o.errors()));
        register(job);
    }

    public void recordFailure(String job, Instant at) {
        stats.merge(job, new Stat(null, at, 1, 1),
                (o, n) -> new Stat(o.lastSuccess(), at, o.runs() + 1, o.errors() + 1));
        register(job).increment();
    }

    public Optional<Stat> stat(String job) {
        return Optional.ofNullable(stats.get(job));
    }

    /** Ilk gorulmede gauge + sayaci kaydeder (sayac donulur; basari yolunda artirilmaz). */
    private Counter register(String job) {
        return counters.computeIfAbsent(job, j -> {
            try {
                Gauge.builder("bu.scheduler.last.success.seconds", this, m -> m.lastSuccessSeconds(j))
                        .tag("job", j).description("Zamanlayicinin son basarili calisma zamani (epoch sn)")
                        .register(registry);
                return Counter.builder("bu.scheduler.errors").tag("job", j)
                        .description("Zamanlayici hata sayisi").register(registry);
            } catch (RuntimeException e) {
                return Counter.builder("bu.scheduler.errors.unregistered").register(new io.micrometer.core.instrument.simple.SimpleMeterRegistry());
            }
        });
    }

    private double lastSuccessSeconds(String job) {
        Stat s = stats.get(job);
        return s == null || s.lastSuccess() == null ? Double.NaN : s.lastSuccess().getEpochSecond();
    }
}
