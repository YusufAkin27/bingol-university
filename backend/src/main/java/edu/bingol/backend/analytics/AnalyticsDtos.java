package edu.bingol.backend.analytics;

import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.List;
import java.util.Map;

public final class AnalyticsDtos {

    private AnalyticsDtos() {}

    /** name: [a-z0-9_]{1,40}; props: en cok 5 anahtar (skaler deger, <=100 karakter); at bos ise sunucu saati. */
    public record EventIn(String name, String screen, Map<String, Object> props, Instant at) {}

    public record EventsRequest(@NotNull List<EventIn> events) {}
}
