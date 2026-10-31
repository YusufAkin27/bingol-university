package edu.bingol.backend.post;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** T-075 (A2-14): sonum kaynakli kucuk puan degisimleri yazilmaz; anlamli degisim yazilir. */
class PostRankWriteThresholdTest {

    @Test
    void tinyDecayDriftIsSkipped() {
        assertFalse(PostRankService.shouldWrite(5.0, 4.99));   // %0,2
        assertFalse(PostRankService.shouldWrite(0.0, 0.0004)); // mutlak esik altinda
        assertFalse(PostRankService.shouldWrite(0.0, 0.0));
    }

    @Test
    void meaningfulChangeIsWritten() {
        assertTrue(PostRankService.shouldWrite(5.0, 4.9));     // %2
        assertTrue(PostRankService.shouldWrite(0.0, 0.5));     // yeni begeni
        assertTrue(PostRankService.shouldWrite(2.0, 0.0));     // sifirlama
    }

    @Test
    void driftAccumulatesAgainstStoredValueSoStaleScoresEventuallyRefresh() {
        double stored = 10.0;
        double actual = 10.0;
        int writes = 0;
        for (int i = 0; i < 100; i++) {
            actual *= 0.998; // ~%0,2 sonum / tur
            if (PostRankService.shouldWrite(stored, actual)) {
                stored = actual;
                writes++;
            }
        }
        assertTrue(writes > 0 && writes < 100, "yazma sayisi " + writes);
    }
}
