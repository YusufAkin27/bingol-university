package edu.bingol.backend.common;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import java.util.function.Supplier;
import org.springframework.stereotype.Component;

/**
 * Kritik yazma akislari (gonderi/forum/etkinlik olusturma, RSVP, oy) icin tek olcum noktasi.
 * Zamanlayici {@code bu.write} (etiketler: {@code op}, {@code outcome}=ok|error); sayac degeri zamanlayicinin
 * {@code count}'udur (ayri sayac yok). Olcum hatasi isi bozmaz; kayit defteri yoksa is aynen calisir.
 * Ad listesi: docs/changes/ops.md "Yazma akisi olcumleri".
 */
@Component
public class WriteMetrics {

    public static final String TIMER = "bu.write";
    private final MeterRegistry registry;

    public WriteMetrics(org.springframework.beans.factory.ObjectProvider<MeterRegistry> registry) {
        this.registry = registry.getIfAvailable();
    }

    public <T> T time(String op, Supplier<T> work) {
        if (registry == null) {
            return work.get();
        }
        long t0 = System.nanoTime();
        String outcome = "ok";
        try {
            return work.get();
        } catch (RuntimeException e) {
            outcome = "error";
            throw e;
        } finally {
            record(op, outcome, System.nanoTime() - t0);
        }
    }

    private void record(String op, String outcome, long nanos) {
        try {
            Timer.builder(TIMER).tag("op", op).tag("outcome", outcome).register(registry)
                    .record(nanos, java.util.concurrent.TimeUnit.NANOSECONDS);
        } catch (RuntimeException ignored) {
            // olcum yazma akisini asla bozmaz
        }
    }

    /** Bean yoksa (birim testleri) dogrudan calistirir. */
    public static <T> T of(WriteMetrics m, String op, Supplier<T> work) {
        return m == null ? work.get() : m.time(op, work);
    }
}
