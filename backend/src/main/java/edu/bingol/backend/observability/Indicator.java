package edu.bingol.backend.observability;

import java.util.Map;

/**
 * Tek gosterge: durum, olculen deger (sayi/metin/null), esikler ({@code warn}, {@code crit}; yoksa null) ve kisa mesaj
 * (yalniz OK degilse; istek dilinde).
 */
public record Indicator(IndicatorStatus status, Object value, Map<String, Object> threshold, String message) {

    public static Indicator ok(Object value, Map<String, Object> threshold) {
        return new Indicator(IndicatorStatus.OK, value, threshold, null);
    }

    public static Indicator unknown(String message) {
        return new Indicator(IndicatorStatus.UNKNOWN, null, null, message);
    }

    /** Sayisal deger icin esik kiyasi: value >= crit CRIT, >= warn WARN (esik 0 veya negatifse o kademe kapali). */
    public static IndicatorStatus byThreshold(double value, double warn, double crit) {
        if (crit > 0 && value >= crit) {
            return IndicatorStatus.CRIT;
        }
        if (warn > 0 && value >= warn) {
            return IndicatorStatus.WARN;
        }
        return IndicatorStatus.OK;
    }
}
