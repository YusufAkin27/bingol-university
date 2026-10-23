package edu.bingol.backend.export;

import java.util.function.Function;

/**
 * KVKK "verilerime erisim" hakki: kullanicinin kendi verilerini disari aktaran modul parcasi.
 * Her modul kendi verisi icin bir bean kaydeder; {@link DataExportController} hepsini birlestirir.
 */
public interface DataExporter {

    /** JSON'daki bolum adi (ornek: "profile", "tickets"). */
    String section();

    /** Kullaniciya ait veri; JSON'a serilestirilebilir olmali. Baskalarinin kisisel verisini icermemelidir. */
    Object export(Long userId);

    static DataExporter of(String section, Function<Long, Object> fn) {
        return new DataExporter() {
            @Override
            public String section() {
                return section;
            }

            @Override
            public Object export(Long userId) {
                return fn.apply(userId);
            }
        };
    }
}
