package edu.bingol.backend.news;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import edu.bingol.backend.common.ApiException;
import java.time.LocalDate;
import java.util.List;
import org.jsoup.Jsoup;
import org.junit.jupiter.api.Test;

class NewsParsingTest {

    @Test
    void parsesNumericIsoAndTurkishMonthDates() {
        assertEquals(LocalDate.of(2026, 10, 5), NewsDates.parse("5.10.2026"));
        assertEquals(LocalDate.of(2026, 10, 5), NewsDates.parse("05/10/2026 14:30"));
        assertEquals(LocalDate.of(2026, 10, 5), NewsDates.parse("2026-10-05"));
        assertEquals(LocalDate.of(2026, 2, 3), NewsDates.parse("3 Şubat 2026"));
        assertEquals(LocalDate.of(2026, 9, 15), NewsDates.parse("15 EYLÜL 2026"));
        assertEquals(LocalDate.of(2026, 12, 1), NewsDates.parse("1 Aralık 2026"));
    }

    @Test
    void invalidDatesYieldNull() {
        assertNull(NewsDates.parse("31.02.2026"));
        assertNull(NewsDates.parse("yakinda"));
        assertNull(NewsDates.parse("  "));
        assertNull(NewsDates.parse(null));
    }

    @Test
    void relativeLinksBecomeAbsoluteAndLongOnesAreSkipped() {
        String longHref = "https://www.bingol.edu.tr/" + "a".repeat(1000);
        String html = """
                <table><tr id="grid_DXDataRow0"><td><a href="/tr/haberler/x">Goreli</a></td><td class="dx-ac">1.2.2026</td></tr>
                <tr id="grid_DXDataRow1"><td><a href="%s">Uzun</a></td><td class="dx-ac">1.2.2026</td></tr>
                <tr id="grid_DXDataRow2"><td><a href="ayrinti.aspx?id=3">Alt</a></td><td class="dx-ac">yakinda</td></tr></table>"""
                .formatted(longHref);

        List<NewsScraper.ListEntry> rows = NewsScraper.parseList(Jsoup.parse(html));

        assertEquals(2, rows.size());
        assertEquals("https://www.bingol.edu.tr/tr/haberler/x", rows.get(0).url());
        assertEquals("https://www.bingol.edu.tr/buproject/ayrinti.aspx?id=3", rows.get(1).url());
        assertNull(rows.get(1).date());
    }

    @Test
    void extractsLabeledEventDate() {
        assertEquals(LocalDate.of(2026, 11, 12),
                NewsScraper.extractEventDate("Konferans\nEtkinlik Tarihi: 12 Kasım 2026\nSaat 10:00"));
        assertEquals(LocalDate.of(2026, 11, 12), NewsScraper.extractEventDate("Tarih: 12.11.2026"));
        assertNull(NewsScraper.extractEventDate("Yayın tarihi 12.11.2026 olan duyuru"));
        assertNull(NewsScraper.extractEventDate(null));
    }

    @Test
    void contentTypeParseIsCaseAndLocaleTolerant() {
        assertEquals(ContentType.DUYURU, ContentType.parse("duyuru"));
        assertEquals(ContentType.ETKINLIK, ContentType.parse(" Etkinlik "));
        assertEquals(ContentType.ETKINLIK, ContentType.parse("ETKİNLİK"));
        assertNull(ContentType.parse(" "));
        assertNull(ContentType.parse(null));
    }

    @Test
    void invalidTypeIsReportedAsBadRequest() {
        ApiException e = assertThrows(ApiException.class, () -> NewsService.parseType("kitap"));
        assertEquals("NEWS_TYPE_INVALID", e.code());
        assertEquals(ContentType.HABER, NewsService.parseType("haber"));
    }
}
