package edu.bingol.backend.admin;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.Arrays;
import org.junit.jupiter.api.Test;

class CsvTest {

    @Test
    void formulaPrefixesAreNeutralised() {
        assertEquals("\"'=1+1\"", Csv.cell("=1+1"));
        assertEquals("\"'+90555\"", Csv.cell("+90555"));
        assertEquals("\"'-2\"", Csv.cell("-2"));
        assertEquals("\"'@SUM(A1)\"", Csv.cell("@SUM(A1)"));
        assertEquals("\"'\tx\"", Csv.cell("\tx"));
        assertEquals("\"'\rx\"", Csv.cell("\rx"));
    }

    @Test
    void plainValuesStayAsIs() {
        assertEquals("Ali Veli", Csv.cell("Ali Veli"));
        assertEquals("42", Csv.cell(42));
        assertEquals("", Csv.cell(null));
        // Ortada gecen '=' veya '-' tehlikesizdir
        assertEquals("a=b-c", Csv.cell("a=b-c"));
    }

    @Test
    void quotesCommasAndNewlinesAreEscaped() {
        assertEquals("\"a,b\"", Csv.cell("a,b"));
        assertEquals("\"he said \"\"hi\"\"\"", Csv.cell("he said \"hi\""));
        assertEquals("\"line1\nline2\"", Csv.cell("line1\nline2"));
    }

    @Test
    void rowEndsWithCrlfAndKeepsEmptyCells() {
        assertEquals("1,,x\r\n", Csv.row(Arrays.asList(1, null, "x")));
    }

    @Test
    void bomIsUtf8Marker() {
        assertEquals(0xFEFF, Csv.BOM.charAt(0));
    }
}
