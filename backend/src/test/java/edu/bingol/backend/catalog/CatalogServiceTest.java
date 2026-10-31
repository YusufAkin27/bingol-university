package edu.bingol.backend.catalog;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.catalog.CatalogService.Department;
import edu.bingol.backend.catalog.CatalogService.DepartmentHit;
import edu.bingol.backend.catalog.CatalogService.Faculty;
import edu.bingol.backend.catalog.CatalogService.Grade;
import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.Lang;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

class CatalogServiceTest {

    private final CatalogService svc = new CatalogService();

    @Test
    void schemaIsConsistent() {
        var c = svc.catalog();
        assertEquals(2, c.version());
        int total = 0;
        Set<String> facultyIds = new HashSet<>();
        Pattern slug = Pattern.compile("[a-z0-9]+(-[a-z0-9]+)*");
        for (Faculty f : c.faculties()) {
            assertTrue(facultyIds.add(f.id()), "tekrar eden fakulte id: " + f.id());
            assertFalse(f.name().isBlank());
            assertTrue(slug.matcher(f.id()).matches());
            Set<String> ids = new HashSet<>();
            Set<String> names = new HashSet<>();
            for (Department d : f.departments()) {
                assertFalse(d.name().isBlank(), "bos ad: " + f.id());
                assertTrue(slug.matcher(d.id()).matches(), "gecersiz slug: " + d.id());
                assertTrue(ids.add(d.id()), "tekrar eden bolum id: " + f.id() + "/" + d.id());
                assertTrue(names.add(d.name()), "tekrar eden bolum adi: " + f.id() + "/" + d.name());
                total++;
            }
        }
        assertTrue(total >= 300, "bolum sayisi: " + total);
        assertEquals(List.of("PREP", "1", "2", "3", "4", "5", "6", "MASTER", "PHD"),
                c.grades().stream().map(g -> g.id()).toList());
    }

    @Test
    void validityChecksFacultyAndDepartmentTogether() {
        assertTrue(svc.isValid("Mühendislik Fakültesi", "Bilgisayar Mühendisliği"));
        assertFalse(svc.isValid("Hukuk Fakültesi", "Bilgisayar Mühendisliği"));
        assertFalse(svc.isValid("Uydurma Fakülte", "Hukuk"));
        assertFalse(svc.isValid(null, "Hukuk"));
        assertTrue(svc.facultyNames().contains("Tıp Fakültesi"));
    }

    @Test
    void requireValidRules() {
        assertDoesNotThrow(() -> svc.requireValid(null, null, null));
        assertDoesNotThrow(() -> svc.requireValid("Hukuk Fakültesi", "Hukuk", "3"));
        assertDoesNotThrow(() -> svc.requireValid(null, null, "PHD"));
        for (String[] bad : new String[][]{
                {"Hukuk Fakültesi", "Tıp", "1"}, {null, "Hukuk", null}, {"Yok", null, null}, {null, null, "9"}}) {
            ApiException e = assertThrows(ApiException.class, () -> svc.requireValid(bad[0], bad[1], bad[2]));
            assertEquals("ACADEMIC_INVALID", e.code());
            assertEquals(400, e.status().value());
        }
    }

    @Test
    void searchIsAccentAndCaseInsensitive() {
        List<DepartmentHit> hits = svc.search("MUH", 30);
        assertFalse(hits.isEmpty());
        assertTrue(hits.stream().allMatch(h -> h.department().toLowerCase(java.util.Locale.ROOT).contains("m")
                || h.faculty().toLowerCase(java.util.Locale.ROOT).contains("m")));
        assertTrue(hits.stream().anyMatch(h -> h.department().equals("Makine Mühendisliği"))
                || hits.stream().anyMatch(h -> h.department().contains("Mühendisliği")));
        assertTrue(svc.search("bilgisayar muhendisligi", 5).stream()
                .anyMatch(h -> h.department().equals("Bilgisayar Mühendisliği")));
        assertTrue(svc.search("İŞLETME", 30).stream().anyMatch(h -> h.department().equals("İşletme")));
        assertTrue(svc.search("isletme", 30).stream().anyMatch(h -> h.department().equals("İşletme")));
        assertEquals("Hukuk", svc.search("hukuk", 1).get(0).department());
    }

    @Test
    void searchMatchesFacultyNameAndCapsResults() {
        assertTrue(svc.search("muh", 30).size() <= 30);
        assertEquals(30, svc.search("muh", 1000).size());
        assertTrue(svc.search("Mühendislik Fakültesi", 30).stream()
                .anyMatch(h -> h.faculty().equals("Mühendislik Fakültesi")));
        assertTrue(svc.search("  ", 10).isEmpty());
        assertTrue(svc.search("zzzzqq", 10).isEmpty());
    }

    private static final Pattern ARABIC = Pattern.compile("[\u0600-\u06FF]");

    /** Ham JSON'da (yedege dusmeden) her fakulte/bolum/sinifin EN ve AR adi dolu olmali. */
    @Test
    void everyEntryHasEnglishAndArabicNamesInTheRawJson() throws Exception {
        JsonNode root;
        try (InputStream in = new ClassPathResource(CatalogService.RESOURCE).getInputStream()) {
            root = JsonMapper.builder().build().readTree(in);
        }
        int count = 0;
        for (JsonNode f : root.get("faculties")) {
            checkNames(f, f.get("id").asText());
            count++;
            for (JsonNode d : f.get("departments")) {
                checkNames(d, f.get("id").asText() + "/" + d.get("id").asText());
                count++;
            }
        }
        for (JsonNode g : root.get("grades")) {
            checkNames(g, "grade " + g.get("id").asText());
            count++;
        }
        assertTrue(count > 700, "kayit sayisi: " + count);
    }

    private static void checkNames(JsonNode n, String where) {
        String en = n.path("nameEn").asText("");
        String ar = n.path("nameAr").asText("");
        assertFalse(en.isBlank(), "nameEn bos: " + where);
        assertFalse(ar.isBlank(), "nameAr bos: " + where);
        assertFalse(ARABIC.matcher(en).find(), "nameEn Arapca harf iceriyor: " + where);
        assertTrue(ARABIC.matcher(ar).find(), "nameAr Arapca harf icermiyor: " + where);
    }

    /** Kanonik Turkce adlar ve kimlikler (DB'de saklanan/eslestirilen anahtar) hic degismemeli. */
    @Test
    void canonicalTurkishNamesAreUnchanged() throws Exception {
        List<String> expected;
        try (InputStream in = new ClassPathResource("catalog/academic-canonical.txt").getInputStream()) {
            expected = new String(in.readAllBytes(), StandardCharsets.UTF_8).lines().toList();
        }
        List<String> actual = new ArrayList<>();
        for (Faculty f : svc.catalog().faculties()) {
            actual.add("F|" + f.id() + "|" + f.name());
            for (Department d : f.departments()) {
                actual.add("D|" + f.id() + "|" + d.id() + "|" + d.name());
            }
        }
        for (Grade g : svc.catalog().grades()) {
            actual.add("G|" + g.id() + "|" + g.name());
        }
        assertEquals(expected, actual);
    }

    @Test
    void displayNamesFollowLanguageAndFallBackToCanonical() {
        assertEquals("Mühendislik Fakültesi", svc.facultyName("Mühendislik Fakültesi", Lang.TR));
        assertEquals("Faculty of Engineering", svc.facultyName("Mühendislik Fakültesi", Lang.EN));
        assertEquals("كلية الهندسة", svc.facultyName("Mühendislik Fakültesi", Lang.AR));
        assertEquals("Computer Engineering", svc.departmentName("Bilgisayar Mühendisliği", "Mühendislik Fakültesi", Lang.EN));
        assertEquals("هندسة الحاسوب", svc.departmentName("Bilgisayar Mühendisliği", null, Lang.AR));
        // katalogta olmayan / null deger aynen doner
        assertEquals("Uydurma Bolum", svc.departmentName("Uydurma Bolum", null, Lang.EN));
        assertEquals("Yok", svc.facultyName("Yok", Lang.AR));
        assertEquals(null, svc.facultyName(null, Lang.EN));
        // eksik ceviri Turkceye duser
        Faculty f = new Faculty("x", "Deneme Fakültesi", null, " ", List.of(new Department("d", "Deneme Bölümü", "", null)));
        assertEquals("Deneme Fakültesi", f.name(Lang.EN));
        assertEquals("Deneme Fakültesi", f.name(Lang.AR));
        assertEquals("Deneme Bölümü", f.departments().get(0).name(Lang.AR));
        assertEquals("Hazırlık", new Grade("PREP", "Hazırlık", null, null).name(Lang.EN));
    }

    @Test
    void searchMatchesEnglishAndArabicNamesToo() {
        assertTrue(svc.search("computer engineering", 10).stream()
                .anyMatch(h -> h.department().equals("Bilgisayar Mühendisliği")));
        assertTrue(svc.search("هندسة الحاسوب", 10).stream()
                .anyMatch(h -> h.department().equals("Bilgisayar Mühendisliği")
                        && h.departmentEn().equals("Computer Engineering")));
        assertTrue(svc.search("faculty of law", 30).stream().anyMatch(h -> h.faculty().equals("Hukuk Fakültesi")));
    }
}
