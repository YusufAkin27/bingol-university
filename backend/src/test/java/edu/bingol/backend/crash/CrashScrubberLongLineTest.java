package edu.bingol.backend.crash;

import static org.assertj.core.api.Assertions.assertThat;

import edu.bingol.backend.observability.LogMasking;
import org.junit.jupiter.api.Test;

/**
 * FIX-P09 (A08#10): acik uc 12000 karakterlik tek satir gonderebilir; e-posta deseni onden sinirsiz oldugu icin
 * ikinci dereceden maliyet (her baslangicta tum kosuyu tarayip geri doner) CPU yer. Satir once kirpilir, desenler
 * yalniz kosu basindan denenir.
 */
class CrashScrubberLongLineTest {

    @Test
    void longSingleLineStackIsScrubbedQuickly() {
        String raw = "a".repeat(12000);
        CrashScrubber.stack(raw); // isinma (sinif yukleme, regex derleme)
        long t0 = System.nanoTime();
        String out = CrashScrubber.stack(raw);
        long ms = (System.nanoTime() - t0) / 1_000_000;
        assertThat(ms).isLessThan(50);
        assertThat(out.length()).isLessThanOrEqualTo(CrashScrubber.MAX_LINE_CHARS);
    }

    @Test
    void longMessageAndErrorTypeAreBoundedAndQuick() {
        String raw = "b".repeat(12000);
        CrashScrubber.text(raw, 300);
        long t0 = System.nanoTime();
        String out = CrashScrubber.text(raw, 300);
        long ms = (System.nanoTime() - t0) / 1_000_000;
        assertThat(ms).isLessThan(50);
        assertThat(out).hasSize(300);
    }

    @Test
    void logMaskingScrubIsLinearOnLongRuns() {
        String raw = "c".repeat(12000);
        LogMasking.scrub(raw);
        long t0 = System.nanoTime();
        LogMasking.scrub(raw);
        long ms = (System.nanoTime() - t0) / 1_000_000;
        assertThat(ms).isLessThan(50);
    }

    @Test
    void emailMaskingStillWorksAtRunStartAndMidLine() {
        assertThat(CrashScrubber.stack("hata ali.veli@bingol.edu.tr verdi")).contains("[eposta]")
                .doesNotContain("ali.veli");
        assertThat(CrashScrubber.stack("ali.veli@bingol.edu.tr")).contains("[eposta]");
        assertThat(CrashScrubber.stack("x=(ali.veli@bingol.edu.tr)")).contains("[eposta]")
                .doesNotContain("ali.veli");
        assertThat(LogMasking.scrub("kullanici ali.veli@bingol.edu.tr")).contains("a***@bingol.edu.tr");
    }

    @Test
    void secretStraddlingTheCutoffIsStillMasked() {
        // e-posta 300. karakteri kapsiyor: kirpmadan once maskelenmeli (kismi adres sizmasin)
        String raw = "x".repeat(290) + " ali.veli@bingol.edu.tr";
        String out = CrashScrubber.stack(raw);
        assertThat(out).doesNotContain("ali.veli").doesNotContain("@bingol");
    }
}
