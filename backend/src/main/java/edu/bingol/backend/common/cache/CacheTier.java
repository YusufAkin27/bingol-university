package edu.bingol.backend.common.cache;

import edu.bingol.backend.config.CacheProperties;
import java.time.Duration;

/** Onbellek sinifi: TTL `app.cache.*` ayarlarindan gelir. */
public enum CacheTier {
    /** Nadiren degisir (ayar, sozlesme, SSS); yazmada gecersiz kilinir. */
    STABLE,
    /** Gunluk senkron/yonetici guncellemesiyle degisir (menu, haber); yazmada gecersiz kilinir. */
    DAILY,
    /** Kisa omurlu (kaynak durumu, kategori sayilari). */
    SHORT;

    Duration ttl(CacheProperties p) {
        return switch (this) {
            case STABLE -> p.stableTtl();
            case DAILY -> p.dailyTtl();
            case SHORT -> p.shortTtl();
        };
    }
}
