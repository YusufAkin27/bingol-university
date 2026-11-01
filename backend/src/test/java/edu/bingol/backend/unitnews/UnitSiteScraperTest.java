package edu.bingol.backend.unitnews;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;
import org.jsoup.Jsoup;
import org.jsoup.nodes.Document;
import org.junit.jupiter.api.Test;

/** Alt site (butema sablonu) ayristirma: liste, detay + ekler, bolumler, bolum akisi baglantisi. Ag yok (kayitli HTML). */
class UnitSiteScraperTest {

    private static Document doc(String file, String base) throws IOException {
        try (InputStream in = UnitSiteScraperTest.class.getResourceAsStream("/unitnews/" + file)) {
            assertNotNull(in, file);
            return Jsoup.parse(new String(in.readAllBytes(), StandardCharsets.UTF_8), base);
        }
    }

    @Test
    void listParsesEntriesAndIgnoresLinksOutsideTheFeed() throws IOException {
        List<UnitSiteScraper.ListEntry> list =
                UnitSiteScraper.parseList(doc("list.html", "https://mmf.bingol.edu.tr/duyurular/"), "/duyurular/");
        assertEquals(5, list.size(), "yan menudeki /haberler/ baglantisi sayilmaz");
        UnitSiteScraper.ListEntry first = list.get(0);
        assertTrue(first.url().startsWith("https://mmf.bingol.edu.tr/duyurular/dunyanin-en-etkili"));
        assertEquals("Dünyanın En Etkili Bilim İnsanları Listesi’nde Fakültemizden 4 isim", first.title());
        assertEquals(LocalDate.of(2026, 10, 9), first.date());
    }

    @Test
    void detailExtractsBodyAndPdfAttachment() throws IOException {
        UnitSiteScraper.Detail d = UnitSiteScraper.parseDetail(doc("detail.html", "https://mmf.bingol.edu.tr/duyurular/x/"));
        assertTrue(d.body().contains("Önceki Öğrenmenin Tanınması Yönergesi"), d.body());
        assertEquals(1, d.attachments().size());
        UnitSiteScraper.Attachment a = d.attachments().get(0);
        assertEquals("https://fbe.bingol.edu.tr/media/51493/bingol-universitesi-onceki-ogrenmenin-taninmasi-yonergesi.pdf", a.url());
        assertEquals("PDF", a.type());
        assertTrue(a.name().startsWith("Bingöl Üniversitesi"));
    }

    @Test
    void departmentsComeFromMenuLinksAndSkipPlannedOnes() throws IOException {
        Document home = doc("home_nav.html", "https://mmf.bingol.edu.tr/");
        List<UnitSiteScraper.Dept> depts = UnitSiteScraper.parseDepartments(home, null);
        assertTrue(depts.size() >= 3, depts.toString());
        assertTrue(depts.stream().noneMatch(d -> d.slug().contains("planlanan")));
        assertTrue(depts.stream().anyMatch(d -> d.slug().equals("bilgisayar-muhendisligi")
                && UnitKeys.deptKey(d.name()).equals("bilgisayar muhendisligi")));
    }

    @Test
    void programsListedAsPlainTextBecomeDepartments() throws IOException {
        Document home = Jsoup.parse("<html><body></body></html>", "https://gencmyo.bingol.edu.tr/");
        List<UnitSiteScraper.Dept> depts = UnitSiteScraper.parseDepartments(home,
                doc("program_list.html", "https://gencmyo.bingol.edu.tr/bolumler/"));
        assertTrue(depts.stream().anyMatch(d -> "bilgisayar teknolojileri".equals(UnitKeys.deptKey(d.name()))), depts.toString());
        assertTrue(depts.stream().allMatch(d -> d.slug().startsWith("x-")));
    }

    @Test
    void feedPathIsFoundOnDepartmentPage() throws IOException {
        assertEquals("/bolumler_/bilgisayar-muhendisligi/duyurular/",
                UnitSiteScraper.parseFeedPath(doc("dept_page.html", "https://mmf.bingol.edu.tr/bolumler/bilgisayar-muhendisligi/")));
        assertNull(UnitSiteScraper.parseFeedPath(Jsoup.parse("<a href='/hakkimizda/'>x</a>")));
    }

    @Test
    void urlsMustBeHttpsOnBingolDomainsAndHttpIsUpgraded() {
        String host = "mmf.bingol.edu.tr";
        assertEquals("https://mmf.bingol.edu.tr/x/", UnitSiteScraper.safeUrl("http://mmf.bingol.edu.tr/x/", host));
        assertEquals("https://mmf.bingol.edu.tr/media/1/a.pdf", UnitSiteScraper.safeUrl("/media/1/a.pdf", host));
        assertNull(UnitSiteScraper.safeUrl("https://evil.example/a.pdf", host));
        assertNull(UnitSiteScraper.safeUrl("https://bingol.edu.tr.evil.example/a.pdf", host));
        assertNull(UnitSiteScraper.safeUrl("javascript:alert(1)", host));
        assertNull(UnitSiteScraper.safeUrl("https://mmf.bingol.edu.tr/" + "a".repeat(600), host));
    }

    @Test
    void deptKeyFoldsTurkishLettersHyphensSuffixesAndParentheses() {
        assertEquals("bilgisayar muhendisligi", UnitKeys.deptKey("Bilgisayar Mühendisliği Bölümü"));
        assertEquals("elektrik-elektronik muhendisligi", UnitKeys.deptKey("Elektrik - Elektronik Mühendisliği"));
        assertEquals("isletme", UnitKeys.deptKey("İŞLETME (İkinci Öğretim) Bölümü"));
        assertEquals("bilgisayar teknolojileri", UnitKeys.deptKey("Bilgisayar Teknolojileri Bölümü"));
        assertNull(UnitKeys.deptKey("  "));
    }
}
