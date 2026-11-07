package edu.bingol.backend.menu;

import static org.junit.jupiter.api.Assertions.*;

import edu.bingol.backend.menu.dto.MenuDish;
import edu.bingol.backend.menu.dto.MenuResponse;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Menu bildirimi yuku: kalori YALNIZ eksiksizse, gorsel YALNIZ varsa; hedef MEAL. */
class MealMenuNotifierTest {

    private static MenuResponse menu(Integer total, boolean complete, String image) {
        return new MenuResponse("2026-11-05", List.of("Mercimek", "Pilav"), image,
                List.of(new MenuDish("Mercimek", 100), new MenuDish("Pilav", complete ? 200 : null)), total, complete);
    }

    @Test
    void totalKcalOnlyWhenComplete() {
        Map<String, String> d = MealMenuNotifier.data(menu(300, true, null));
        assertEquals("MEAL", d.get("target"));
        assertEquals("2026-11-05", d.get("value"));
        assertEquals("2026-11-05", d.get("mealDate"));
        assertEquals("300", d.get("totalKcal"));

        Map<String, String> partial = MealMenuNotifier.data(menu(100, false, null));
        assertFalse(partial.containsKey("totalKcal"), "eksik kalori toplami gosterilmez");
    }

    @Test
    void imageOnlyWhenMenuHasContentImage() {
        assertFalse(MealMenuNotifier.data(menu(null, false, null)).containsKey("imageUrl"));
        assertFalse(MealMenuNotifier.data(menu(null, false, "  ")).containsKey("imageUrl"));
        assertEquals("/files/menu/1.jpg", MealMenuNotifier.data(menu(null, false, "/files/menu/1.jpg")).get("imageUrl"));
    }
}
