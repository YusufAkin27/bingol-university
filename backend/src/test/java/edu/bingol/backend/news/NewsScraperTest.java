package edu.bingol.backend.news;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.List;
import org.jsoup.Jsoup;
import org.junit.jupiter.api.Test;

class NewsScraperTest {

    private static final String LIST_HTML = """
            <table><tr id="grid_DXDataRow0" class="dxgvDataRow_CrmTheme">
              <td class="dxgv"><a href=http://www.bingol.edu.tr/tr/haberler/ornek-haber target=_parent>Örnek Haber</a></td>
              <td class="dxgv dx-ac">21.10.2026</td></tr>
            <tr id="grid_DXDataRow1"><td><a href=https://oidb.bingol.edu.tr/duyurular/x/ target=_parent>Harici</a></td>
              <td class="dx-ac">5.1.2026</td></tr>
            <tr id="grid_DXEmptyRow"><td>bos</td></tr></table>""";

    @Test
    void parsesListRowsAndNormalizesLinks() {
        List<NewsScraper.ListEntry> rows = NewsScraper.parseList(Jsoup.parse(LIST_HTML));

        assertEquals(2, rows.size());
        assertEquals("https://www.bingol.edu.tr/tr/haberler/ornek-haber", rows.get(0).url());
        assertEquals("Örnek Haber", rows.get(0).title());
        assertEquals(LocalDate.of(2026, 10, 21), rows.get(0).date());
        assertEquals(LocalDate.of(2026, 1, 5), rows.get(1).date());
    }

    @Test
    void changedPageStructureYieldsEmptyList() {
        assertTrue(NewsScraper.parseList(Jsoup.parse("<html><body><p>Bakımdayız</p></body></html>")).isEmpty());
    }

    @Test
    void summarizeShortensLongText() {
        String s = NewsScraper.summarize("a ".repeat(300));
        assertTrue(s.length() <= 221 && s.endsWith("…"));
    }
}
