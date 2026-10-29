package edu.bingol.backend.menu;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

import edu.bingol.backend.common.ApiException;
import java.time.YearMonth;
import org.junit.jupiter.api.Test;

class MenuServiceTest {

    private final MenuService service = new MenuService(mock(MenuRepository.class), mock(MenuCalorieService.class));

    @Test
    void resolvesMonthOrDefaultsToCurrent() {
        assertEquals(YearMonth.of(2026, 10), service.resolveMonth("2026-10"));
        assertEquals(service.currentMonth(), service.resolveMonth(null));
        assertEquals(service.currentMonth(), service.resolveMonth("  "));
    }

    @Test
    void rejectsMalformedOrOutOfRangeMonth() {
        for (String bad : new String[] {"2026-13", "202610", "abc", "1999-12", "2101-01"}) {
            ApiException e = assertThrows(ApiException.class, () -> service.resolveMonth(bad), bad);
            assertEquals("MENU_MONTH_INVALID", e.code());
        }
    }

    @Test
    void longMenuIsCutAtLineBoundary() {
        String items = "yemek satiri\n".repeat(100).trim();
        String fit = MenuSyncService.fit(items);
        assertTrue(fit.length() <= 1000 && !fit.endsWith("\n"));
        assertEquals("kisa", MenuSyncService.fit("kisa"));
    }
}
