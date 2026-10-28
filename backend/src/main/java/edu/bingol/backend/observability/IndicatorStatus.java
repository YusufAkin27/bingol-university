package edu.bingol.backend.observability;

/** Gosterge durumu. UNKNOWN: olculemiyor/henuz veri yok (uyari tetiklemez). */
public enum IndicatorStatus {
    OK(0), WARN(1), CRIT(2), UNKNOWN(-1);

    private final int metricValue;

    IndicatorStatus(int metricValue) {
        this.metricValue = metricValue;
    }

    /** Prometheus gauge degeri: OK 0, WARN 1, CRIT 2, UNKNOWN -1. */
    public int metricValue() {
        return metricValue;
    }

    /** Iki durumdan kotu olani (UNKNOWN en dusuk onceliklidir: bilinen bir durumu gizlemez). */
    public static IndicatorStatus worse(IndicatorStatus a, IndicatorStatus b) {
        return severity(b) > severity(a) ? b : a;
    }

    private static int severity(IndicatorStatus s) {
        return switch (s) {
            case UNKNOWN -> 0;
            case OK -> 1;
            case WARN -> 2;
            case CRIT -> 3;
        };
    }
}
