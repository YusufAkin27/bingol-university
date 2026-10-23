package edu.bingol.backend.analytics;

import static org.junit.jupiter.api.Assertions.assertEquals;

import edu.bingol.backend.analytics.ReportDtos.Breakdown;
import edu.bingol.backend.analytics.ReportDtos.BreakdownItem;
import edu.bingol.backend.analytics.ReportDtos.KeyCount;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

class AnalyticsReportServiceTest {

    private static Breakdown build(List<KeyCount> rows) {
        return AnalyticsReportService.buildBreakdown("faculty", rows, "Belirtilmemis", "Diger");
    }

    @Test
    void emptyKeysMergeIntoUnknownAndAreSortedByCount() {
        Breakdown b = build(List.of(new KeyCount("Muh", 3), new KeyCount(null, 5), new KeyCount("  ", 2),
                new KeyCount("Fen", 3)));

        assertEquals(13, b.total());
        assertEquals("unknown", b.items().get(0).key());
        assertEquals("Belirtilmemis", b.items().get(0).label());
        assertEquals(7, b.items().get(0).count());
        // Esit sayida olanlar anahtara gore
        assertEquals("Fen", b.items().get(1).key());
        assertEquals("Muh", b.items().get(2).key());
    }

    @Test
    void percentsRoundToOneDecimal() {
        Breakdown b = build(List.of(new KeyCount("A", 1), new KeyCount("B", 2)));

        assertEquals(33.3, b.items().get(1).percent());
        assertEquals(66.7, b.items().get(0).percent());
    }

    @Test
    void foldsBeyond50IntoOther() {
        List<KeyCount> rows = new ArrayList<>();
        for (int i = 0; i < 60; i++) {
            rows.add(new KeyCount(String.format("k%02d", i), 100 - i));
        }
        Breakdown b = build(rows);

        assertEquals(51, b.items().size());
        BreakdownItem other = b.items().get(50);
        assertEquals("other", other.key());
        // Son 10 oge: 100-50 ... 100-59 = 50+49+...+41
        assertEquals(455, other.count());
        assertEquals(b.total(), b.items().stream().mapToLong(BreakdownItem::count).sum());
    }

    @Test
    void emptyDataGivesZeroTotalAndNoDivisionByZero() {
        Breakdown b = build(List.of());

        assertEquals(0, b.total());
        assertEquals(0, b.items().size());
        assertEquals(0.0, AnalyticsReportService.percent(0, 0));
    }
}
