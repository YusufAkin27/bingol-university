package edu.bingol.backend.menu;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.List;
import org.jsoup.Jsoup;
import org.junit.jupiter.api.Test;

class MenuScraperTest {

    private static final String HTML = """
            <div class="sayfa-icerik"><table><tbody>
              <tr><td><p><strong>01.10.2026</strong></p></td><td><p>PATLICAN MUSAKKA</p></td>
                  <td><p>BULGUR PİLAVI</p></td><td><p>OSMANLI ÇORBASI</p></td><td><p>CACIK</p></td></tr>
              <tr><td><p>&nbsp;</p></td><td><p>&nbsp;</p></td><td><p>&nbsp;</p></td></tr>
              <tr><td><p><strong>02.10.2026</strong></p></td><td><p>ORMAN KEBABI</p></td><td><p>&nbsp;</p></td></tr>
            </tbody></table></div>""";

    @Test
    void parsesDaysAndSkipsBlankRows() {
        List<MenuScraper.Day> days = MenuScraper.parse(Jsoup.parse(HTML));

        assertEquals(2, days.size());
        assertEquals(LocalDate.of(2026, 10, 1), days.get(0).date());
        assertEquals(List.of("PATLICAN MUSAKKA", "BULGUR PİLAVI", "OSMANLI ÇORBASI", "CACIK"), days.get(0).items());
        assertEquals(List.of("ORMAN KEBABI"), days.get(1).items());
    }

    @Test
    void changedPageStructureYieldsEmptyList() {
        assertTrue(MenuScraper.parse(Jsoup.parse("<html><body>değişti</body></html>")).isEmpty());
    }
}
