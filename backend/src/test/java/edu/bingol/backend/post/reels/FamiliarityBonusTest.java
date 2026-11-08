package edu.bingol.backend.post.reels;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.post.reels.FamiliarityService.Signals;
import org.junit.jupiter.api.Test;

class FamiliarityBonusTest {

    private static final FamiliarityProperties P = new FamiliarityProperties(true, 0.6, 1.0, 0.5, 0.4, 0.35, 0.15, 2.0);

    @Test
    void signalsOrderAuthors() {
        double none = FamiliarityService.bonus(P, new Signals(false, false, 0, 0, false, false));
        double dept = FamiliarityService.bonus(P, new Signals(false, false, 0, 0, true, true));
        double dm = FamiliarityService.bonus(P, new Signals(false, true, 0, 0, false, false));
        double all = FamiliarityService.bonus(P, new Signals(true, true, 3, 5, true, true));
        assertEquals(0.0, none, 1e-9);
        assertTrue(dept > none, "ayni bolum");
        assertTrue(dm > dept, "birebir sohbet bolumden guclu");
        assertTrue(all > dm, "cok sinyal daha yuksek");
    }

    @Test
    void facultyOnlyWhenDepartmentDiffers() {
        double fac = FamiliarityService.bonus(P, new Signals(false, false, 0, 0, false, true));
        double both = FamiliarityService.bonus(P, new Signals(false, false, 0, 0, true, true));
        assertEquals(0.15, fac, 1e-9);
        assertEquals(0.35, both, 1e-9);
    }

    @Test
    void saturatesAndIsCapped() {
        double three = FamiliarityService.bonus(P, new Signals(false, false, 3, 0, false, false));
        double ten = FamiliarityService.bonus(P, new Signals(false, false, 10, 0, false, false));
        assertEquals(three, ten, 1e-9);
        FamiliarityProperties big = new FamiliarityProperties(true, 5, 5, 5, 5, 5, 5, 2.0);
        assertEquals(2.0, FamiliarityService.bonus(big, new Signals(true, true, 3, 5, true, true)), 1e-9);
    }
}
