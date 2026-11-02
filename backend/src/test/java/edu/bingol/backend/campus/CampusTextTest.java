package edu.bingol.backend.campus;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Arama anahtari, LIKE kacisi, kategori beyaz listesi ve admin dogrulama yardimcilari (birim). */
class CampusTextTest {

    @Test
    void normalizeFoldsTurkishLettersAndCase() {
        assertEquals("muhendislik fakultesi", CampusText.normalize("Mühendislik Fakültesi"));
        assertEquals("mu", CampusText.normalize("mü"));
        assertEquals("mu", CampusText.normalize("MÜ"));
        assertEquals("iktisadi idari bilimler", CampusText.normalize("İktisadi İdari Bilimler"));
        assertEquals("islami ilimler", CampusText.normalize("İSLAMİ İLİMLER"));
        assertEquals("kutuphane", CampusText.normalize("Kütüphane"));
        assertEquals("gida, tarim ve hayvancilik", CampusText.normalize("Gıda, Tarım Ve Hayvancılık"));
        assertEquals("kyk kiz ogrenci yurdu", CampusText.normalize("KYK Kız Öğrenci Yurdu"));
        assertEquals("sosyal alanlar", CampusText.normalize("  Sosyal   Alanlar \n"));
        assertEquals("", CampusText.normalize(null));
    }

    @Test
    void escapeLikeNeutralisesWildcards() {
        assertEquals("100\\%", CampusText.escapeLike("100%"));
        assertEquals("a\\_b", CampusText.escapeLike("a_b"));
        assertEquals("a\\\\b", CampusText.escapeLike("a\\b"));
    }

    @Test
    void unitsKeyJoinsNormalizedUnits() {
        assertEquals("bilgisayar muhendisligi | elektrik", CampusText.unitsKey(List.of("Bilgisayar Mühendisliği", "Elektrik")));
        assertEquals("", CampusText.unitsKey(List.of()));
    }

    @Test
    void categoryWhitelistIsExactAndCaseInsensitive() {
        assertEquals(CampusCategory.FACULTY, CampusCategory.parse(" Faculty "));
        assertNull(CampusCategory.parse("fakulte"));
        assertNull(CampusCategory.parse(null));
        assertEquals(13, CampusCategory.ordered().size());
        for (CampusCategory c : CampusCategory.values()) {
            assertTrue(c.color().matches("#[0-9A-F]{6}"), c.key());
            assertTrue(c.labelKey().startsWith("campus.cat."));
        }
    }

    @Test
    void tileUrlMustBeHttpsWithPlaceholders() {
        CampusAdminService.validateTileUrl("https://tile.openstreetmap.org/{z}/{x}/{y}.png");
        CampusAdminService.validateTileUrl("https://{s}.tiles.example.com/{z}/{x}/{y}{r}.png");
        for (String bad : List.of("http://tile.example.com/{z}/{x}/{y}.png",
                "https://tile.example.com/{z}/{x}.png", "https://tile.example.com/{z}/{x}/{y}/{foo}.png",
                "ftp://tile.example.com/{z}/{x}/{y}.png", "https://user:pw@tile.example.com/{z}/{x}/{y}.png",
                "https://tile.example.com/{z}/{x}/{y}.png ", "https://tile.example.com/{z}/{x}/{y.png",
                "https:///{z}/{x}/{y}.png", "javascript:alert(1)")) {
            ApiException e = assertThrows(ApiException.class, () -> CampusAdminService.validateTileUrl(bad), bad);
            assertEquals("CAMPUS_TILE_URL_INVALID", e.code(), bad);
        }
    }

    @Test
    void webUrlOnlyHttpsOnBingolEduTr() {
        assertNull(CampusAdminService.webUrl(null));
        assertNull(CampusAdminService.webUrl("  "));
        assertEquals("https://mmf.bingol.edu.tr", CampusAdminService.webUrl(" https://mmf.bingol.edu.tr "));
        assertEquals("https://bingol.edu.tr/tr/x", CampusAdminService.webUrl("https://bingol.edu.tr/tr/x"));
        assertEquals("https://www.bingol.edu.tr/tr/kampuste-yasam/saglik",
                CampusAdminService.webUrl("https://www.bingol.edu.tr/tr/kampuste-yasam/saglik"));
        for (String bad : List.of("http://mmf.bingol.edu.tr", "https://evil.com", "https://bingol.edu.tr.evil.com",
                "https://evilbingol.edu.tr", "https://u:p@mmf.bingol.edu.tr", "javascript:alert(1)",
                "https://mmf.bingol.edu.tr/a b", "//mmf.bingol.edu.tr", "https://", "https://x.com/?h=bingol.edu.tr")) {
            ApiException e = assertThrows(ApiException.class, () -> CampusAdminService.webUrl(bad), bad);
            assertEquals("CAMPUS_WEB_URL_INVALID", e.code(), bad);
        }
    }

    @Test
    void pointsRejectDegenerateAndOutOfRange() {
        List<double[]> ok = CampusAdminService.points(List.of(List.of(38.9, 40.4), List.of(38.9, 40.5),
                List.of(39.0, 40.5), List.of(38.9, 40.4)), 10, "CAMPUS_POLYGON_INVALID");
        assertEquals(3, ok.size(), "kapanis noktasi atilir");
        assertThrows(ApiException.class, () -> CampusAdminService.points(
                List.of(List.of(38.9, 40.4), List.of(38.9, 40.5)), 10, "CAMPUS_POLYGON_INVALID"));
        assertThrows(ApiException.class, () -> CampusAdminService.points(
                List.of(List.of(38.9, 40.4), List.of(38.95, 40.45), List.of(39.0, 40.5)), 10, "CAMPUS_POLYGON_INVALID"),
                "dogrusal poligon alansiz");
        ApiException e = assertThrows(ApiException.class, () -> CampusAdminService.points(
                List.of(List.of(91.0, 40.4), List.of(38.9, 40.5), List.of(39.0, 40.6)), 10, "CAMPUS_POLYGON_INVALID"));
        assertEquals("CAMPUS_COORD_INVALID", e.code());
        assertThrows(ApiException.class, () -> CampusAdminService.points(
                List.of(List.of(38.9, 40.4), List.of(38.9, 40.5), List.of(39.0, 40.5), List.of(39.0, 40.4)), 2,
                "CAMPUS_POLYGON_INVALID"), "nokta sayisi siniri");
    }
}
