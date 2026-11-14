package edu.bingol.backend.academician;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.academician.AcCourse.LimitType;
import org.junit.jupiter.api.Test;

/** atRisk / overLimit tek fonksiyondan: duzey 0/1/2. */
class AbsencePolicyTest {

    @Test
    void noLimitMeansNothing() {
        assertEquals(0, AbsencePolicy.level(null, null, 10, 10));
        assertEquals(0, AbsencePolicy.level(LimitType.COUNT, null, 10, 10));
    }

    @Test
    void countLevels() {
        // sinir 4: 3 devamsizlik = bir tane daha sinira ulastirir (risk), 4 = sinira ulasildi
        assertEquals(0, AbsencePolicy.level(LimitType.COUNT, 4, 10, 0));
        assertEquals(0, AbsencePolicy.level(LimitType.COUNT, 4, 10, 2));
        assertEquals(1, AbsencePolicy.level(LimitType.COUNT, 4, 10, 3));
        assertEquals(2, AbsencePolicy.level(LimitType.COUNT, 4, 10, 4));
        assertEquals(2, AbsencePolicy.level(LimitType.COUNT, 4, 10, 7));
        // devamsizligi olmayana risk uyarisi verilmez (sinir 1)
        assertEquals(0, AbsencePolicy.level(LimitType.COUNT, 1, 5, 0));
        assertEquals(2, AbsencePolicy.level(LimitType.COUNT, 1, 5, 1));
    }

    @Test
    void percentUsesExactIntegerComparison() {
        // %20, 10 oturum: 2 devamsizlik = %20 -> ulasildi
        assertEquals(2, AbsencePolicy.level(LimitType.PERCENT, 20, 10, 2));
        // 1 devamsizlik, bir sonraki oturum da kacarsa 2/11 = %18,18 < %20: risk yok
        assertEquals(0, AbsencePolicy.level(LimitType.PERCENT, 20, 10, 1));
        // 1/4 = %25 >= %20 -> ulasildi
        assertEquals(2, AbsencePolicy.level(LimitType.PERCENT, 20, 4, 1));
        // 2/9: %22 ulasildi; 1/9: bir daha kacarsa 2/10 = %20 -> risk
        assertEquals(1, AbsencePolicy.level(LimitType.PERCENT, 20, 9, 1));
        assertEquals(2, AbsencePolicy.level(LimitType.PERCENT, 20, 9, 2));
        // yuvarlama yok: %33 sinir, 3 oturumda 1 devamsizlik = 33,33 >= 33 ulasildi
        assertEquals(2, AbsencePolicy.level(LimitType.PERCENT, 33, 3, 1));
        // oturum yokken ulasilmaz
        assertEquals(0, AbsencePolicy.level(LimitType.PERCENT, 20, 0, 0));
    }

    @Test
    void standingMapsLevelsToApiFlags() {
        assertTrue(AbsencePolicy.standing(LimitType.COUNT, 4, 10, 3).atRisk());
        assertFalse(AbsencePolicy.standing(LimitType.COUNT, 4, 10, 3).overLimit());
        assertTrue(AbsencePolicy.standing(LimitType.COUNT, 4, 10, 4).overLimit());
        assertFalse(AbsencePolicy.standing(LimitType.COUNT, 4, 10, 4).atRisk());
    }
}
