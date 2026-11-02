package edu.bingol.backend.analytics.usage;

/**
 * Ekran suresi dagilimi kovalari (milisaniye). Gece toplulastirmasi (dbmaint.UsageRollup) sureleri bu kovalara
 * sayar, rapor kovalardan medyan hesaplar: ham sure hicbir yerde saklanmaz. Kova i = [EDGES_MS[i], EDGES_MS[i+1]);
 * son kova ust siniri dahildir. Istemci ust siniri 30 dk; fazlasi toplulastirmada atilir.
 */
public final class UsageBuckets {

    public static final long[] EDGES_MS = {0, 1_000, 2_000, 5_000, 10_000, 20_000, 30_000, 60_000, 120_000, 300_000,
            600_000, 1_800_000};
    public static final long MAX_MS = EDGES_MS[EDGES_MS.length - 1];
    public static final int COUNT = EDGES_MS.length - 1;

    private UsageBuckets() {
    }

    /** Sabit sayilardan uretilen SQL ifadesi: {@code col} (ms) -> kova numarasi. Kullanici girdisi icermez. */
    public static String sqlCase(String col) {
        StringBuilder sb = new StringBuilder("CASE");
        for (int i = 1; i < COUNT; i++) {
            sb.append(" WHEN ").append(col).append(" < ").append(EDGES_MS[i]).append(" THEN ").append(i - 1);
        }
        return sb.append(" ELSE ").append(COUNT - 1).append(" END").toString();
    }

    /** Kova sayaclarindan medyan (ms); kova icinde dogrusal ara deger. Veri yoksa -1. */
    public static double medianMs(long[] counts) {
        long total = 0;
        for (long c : counts) {
            total += c;
        }
        if (total == 0) {
            return -1;
        }
        double target = total / 2.0;
        long cum = 0;
        for (int i = 0; i < counts.length && i < COUNT; i++) {
            if (counts[i] > 0 && cum + counts[i] >= target) {
                double frac = (target - cum) / counts[i];
                return EDGES_MS[i] + frac * (EDGES_MS[i + 1] - EDGES_MS[i]);
            }
            cum += counts[i];
        }
        return MAX_MS;
    }
}
