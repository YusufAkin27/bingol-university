package edu.bingol.backend.crypto;

import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.stereotype.Component;

/** Sifreleme hata sayaci (icerik/anahtar bilgisi icermez). Ad: crypto_failures_total{reason}. */
@Component
public class CryptoMetrics {

    private final MeterRegistry registry;

    public CryptoMetrics(MeterRegistry registry) {
        this.registry = registry;
    }

    public void failure(String reason) {
        registry.counter("crypto_failures_total", "reason", reason).increment();
    }
}
