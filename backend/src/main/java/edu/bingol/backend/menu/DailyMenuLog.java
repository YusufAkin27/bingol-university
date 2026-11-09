package edu.bingol.backend.menu;

import java.time.LocalDate;

/** Gunun menusu push'u icin gunluk idempotens kaydi. */
public interface DailyMenuLog {

    /** O gun icin bir deneme kaydi var mi (ucuz hizli yol). */
    boolean exists(LocalDate day);

    /**
     * Gunu ATOMIK olarak sahiplenir (birincil anahtar). Ayni gun ikinci cagri (baska ornek ya da yeniden baslatma) false.
     */
    boolean claim(LocalDate day, String outcome);

    /** Sahiplenilen gunun sonucunu ve kuyruga yazilan sayiyi gunceller. */
    void finish(LocalDate day, String outcome, int enqueued);
}
