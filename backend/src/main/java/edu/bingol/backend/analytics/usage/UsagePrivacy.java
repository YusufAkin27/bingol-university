package edu.bingol.backend.analytics.usage;

/**
 * K-anonimlik esigi: surum/fakulte/bolum kirilimlarinda gunluk kullanicisi k'dan az olan gruplar tek tek
 * gosterilmez ("other" altinda birlesir; o da k'dan azsa hic yazilmaz). Ayar yanlislikla dusurulmesin diye taban 5.
 */
public final class UsagePrivacy {

    public static final int K_FLOOR = 5;
    public static final int K_DEFAULT = 10;

    private UsagePrivacy() {
    }

    public static int effectiveK(int configured) {
        return Math.max(K_FLOOR, configured);
    }
}
