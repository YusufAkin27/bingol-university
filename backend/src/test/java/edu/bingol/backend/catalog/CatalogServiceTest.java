package edu.bingol.backend.catalog;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.catalog.CatalogService.Department;
import edu.bingol.backend.catalog.CatalogService.DepartmentHit;
import edu.bingol.backend.catalog.CatalogService.Faculty;
import edu.bingol.backend.common.ApiException;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

class CatalogServiceTest {

    private final CatalogService svc = new CatalogService();

    @Test
    void schemaIsConsistent() {
        var c = svc.catalog();
        assertEquals(1, c.version());
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
}
