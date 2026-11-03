package edu.bingol.backend.academic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.academic.OfficialTimetableDtos.ImportResult;
import edu.bingol.backend.academic.OfficialTimetableDtos.OfficialView;
import edu.bingol.backend.catalog.CatalogService;
import edu.bingol.backend.common.ApiException;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalTime;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Resmi ders programi: Excel okuma, dogrulama, yerine koyma (idempotent) ve kullanici sorgusu (H2). */
@SpringBootTest
class OfficialTimetableServiceTest {

    static final String TERM = "2026-2027 Güz";
    static final String UNIT = "Teknik Bilimler Meslek Yüksekokulu";
    static final String[] HEADER = {"Dönem", "Birim", "Bölüm / Program", "Sınıf", "Grup / Şube", "Gün", "Başlangıç", "Bitiş",
        "Ders Kodu", "Ders Adı", "Öğretim Elemanı", "Derslik", "Not", "Kaynak"};

    @Autowired JdbcTemplate jdbc;
    OfficialTimetableService svc;

    @BeforeEach
    void setUp() {
        jdbc.update("DELETE FROM official_timetable_entry");
        jdbc.update("DELETE FROM official_timetable_batch");
        jdbc.update("DELETE FROM app_user WHERE email LIKE 'ott-%'");
        svc = new OfficialTimetableService(jdbc, new CatalogService(), new AcademicAudience(jdbc));
    }

    static String[] row(String unit, String prog, String grade, String day, String s, String e, String code, String name) {
        return new String[] {TERM, unit, prog, grade, "", day, s, e, code, name, "Dr. Öğr. Üyesi Ali Veli", "D-16", "",
            "https://x.example/a.xlsx"};
    }

    /** Ortak-dize kullanmayan (inlineStr) en kucuk gecerli .xlsx; ilk sayfa "Özet" (bos), ikinci sayfa verilen ad. */
    static byte[] xlsx(String sheetName, List<String[]> rows) throws IOException {
        StringBuilder sb = new StringBuilder("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                + "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>");
        int r = 1;
        for (String[] row : rows) {
            sb.append("<row r=\"").append(r).append("\">");
            for (int c = 0; c < row.length; c++) {
                char col = (char) ('A' + c);
                sb.append("<c r=\"").append(col).append(r).append("\" t=\"inlineStr\"><is><t>")
                        .append(row[c].replace("&", "&amp;").replace("<", "&lt;")).append("</t></is></c>");
            }
            sb.append("</row>");
            r++;
        }
        sb.append("</sheetData></worksheet>");
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        try (ZipOutputStream z = new ZipOutputStream(bos, StandardCharsets.UTF_8)) {
            put(z, "xl/workbook.xml", "<?xml version=\"1.0\"?><workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" "
                    + "xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>"
                    + "<sheet name=\"Özet\" sheetId=\"1\" r:id=\"rId1\"/><sheet name=\"" + sheetName
                    + "\" sheetId=\"2\" r:id=\"rId2\"/></sheets></workbook>");
            put(z, "xl/_rels/workbook.xml.rels", "<?xml version=\"1.0\"?><Relationships "
                    + "xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
                    + "<Relationship Id=\"rId1\" Target=\"worksheets/sheet1.xml\"/>"
                    + "<Relationship Id=\"rId2\" Target=\"worksheets/sheet2.xml\"/></Relationships>");
            put(z, "xl/worksheets/sheet1.xml", "<?xml version=\"1.0\"?><worksheet "
                    + "xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData/></worksheet>");
            put(z, "xl/worksheets/sheet2.xml", sb.toString());
        }
        return bos.toByteArray();
    }

    static void put(ZipOutputStream z, String name, String body) throws IOException {
        z.putNextEntry(new ZipEntry(name));
        z.write(body.getBytes(StandardCharsets.UTF_8));
        z.closeEntry();
    }

    static byte[] sample() throws IOException {
        return xlsx("Ders Programı", List.of(HEADER,
                row(UNIT, "Bilgisayar Programcılığı", "1", "Pazartesi", "08:15", "10:00", "BIL101", "Programlamaya Giriş"),
                row(UNIT, "Bilgisayar Programcılığı", "2. Sınıf", "Salı", "9.15", "11.00", "BIL201", "Veri Yapıları"),
                row("Fakülte X", "Uydurma Bölüm", "I", "Cuma", "13:15", "15:00", "", "Ders")));
    }

    @Test
    void dryRunReportsAndWritesNothing() throws IOException {
        ImportResult r = svc.importXlsx(null, "a.xlsx", sample(), null, true);
        assertTrue(r.dryRun());
        assertEquals(3, r.rows());
        assertEquals(2, r.programs());
        assertTrue(r.errors().isEmpty());
        assertEquals(1, r.warnings().size(), "katalogda olmayan program uyarisi");
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM official_timetable_entry", Integer.class));
        assertTrue(r.items().get(0).catalogMatched());
        assertEquals(List.of("1", "2"), r.items().get(0).grades());
    }

    @Test
    void reuploadReplacesInsteadOfDuplicating() throws IOException {
        svc.importXlsx(null, "a.xlsx", sample(), null, false);
        ImportResult r = svc.importXlsx(null, "a.xlsx", sample(), null, false);
        assertEquals(2, r.replacedPrograms());
        assertEquals(3, jdbc.queryForObject("SELECT COUNT(*) FROM official_timetable_entry", Integer.class));
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM official_timetable_batch", Integer.class));
    }

    @Test
    void invalidRowsBlockCommit() throws IOException {
        byte[] bad = xlsx("Ders Programı", List.of(HEADER,
                row("U", "P", "9", "Pazartesi", "08:15", "10:00", "", "Ders"),
                row("U", "P", "1", "Pazartesi", "10:00", "09:00", "", "Ders2")));
        ImportResult prev = svc.importXlsx(null, "b.xlsx", bad, null, true);
        assertEquals(2, prev.errors().size());
        ApiException e = assertThrows(ApiException.class, () -> svc.importXlsx(null, "b.xlsx", bad, null, false));
        assertEquals("TIMETABLE_IMPORT_INVALID", e.code());
    }

    @Test
    void userSeesOnlyOwnDepartmentAndGradeAndPublished() throws IOException {
        svc.importXlsx(null, "a.xlsx", sample(), null, false);
        jdbc.update("INSERT INTO app_user (email, password_hash, display_name, email_verified, role, status, department, "
                + "faculty, grade, language, show_email, created_at) VALUES ('ott-1@bingol.edu.tr', 'x', 'T', TRUE, 'USER', "
                + "'ACTIVE', 'Bilgisayar Programcılığı', 'Meslek Yüksekokulu', '2', 'tr', FALSE, CURRENT_TIMESTAMP)");
        long uid = jdbc.queryForObject("SELECT id FROM app_user WHERE email = 'ott-1@bingol.edu.tr'", Long.class);

        OfficialView v = svc.forUser(uid, null, null, null, null);
        assertEquals(TERM, v.term());
        assertEquals(1, v.items().size());
        assertEquals("BIL201", v.items().get(0).code());
        assertEquals("09:15", v.items().get(0).start());
        assertEquals(2, v.items().get(0).day());

        svc.adminPublish(TERM, UNIT, "Bilgisayar Programcılığı", false);
        assertTrue(svc.forUser(uid, null, null, null, null).items().isEmpty());
    }

    @Test
    void parsersAreTolerant() {
        assertEquals("1", OfficialTimetableService.grade("1. Sınıf"));
        assertEquals("PREP", OfficialTimetableService.grade("Hazırlık"));
        assertEquals("MASTER", OfficialTimetableService.grade("Yüksek Lisans"));
        assertNull(OfficialTimetableService.grade("7"));
        assertEquals(4, OfficialTimetableService.day("PERŞEMBE"));
        assertEquals(1, OfficialTimetableService.day("1"));
        assertEquals(-1, OfficialTimetableService.day("Pzt?"));
        assertEquals(LocalTime.of(8, 15), OfficialTimetableService.time("0.34375"));
        assertEquals(LocalTime.of(8, 15), OfficialTimetableService.time("08.15"));
        assertNull(OfficialTimetableService.time("25:00"));
        assertFalse(OfficialTimetableService.fold("İŞLETME").isEmpty());
    }
}
