package edu.bingol.backend.catalog;

import edu.bingol.backend.common.ApiException;
import java.io.IOException;
import java.io.InputStream;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;

/** Akademik katalog (fakulte/bolum/sinif): acilista classpath JSON'undan yuklenir, bellekte tutulur. */
@Service
public class CatalogService {

    private static final Logger log = LoggerFactory.getLogger(CatalogService.class);
    static final String RESOURCE = "catalog/academic.json";

    public record Department(String id, String name) {}

    public record Faculty(String id, String name, List<Department> departments) {}

    public record Grade(String id, String name) {}

    public record Catalog(int version, List<Faculty> faculties, List<Grade> grades) {}

    public record DepartmentHit(String faculty, String department) {}

    private record Entry(String faculty, String department, String foldedDepartment, String foldedFaculty) {}

    private final Catalog catalog;
    private final List<Entry> entries;
    private final Set<String> gradeIds;

    public CatalogService() {
        this(load(RESOURCE));
    }

    CatalogService(Catalog catalog) {
        this.catalog = catalog;
        List<Entry> list = new ArrayList<>();
        for (Faculty f : catalog.faculties()) {
            for (Department d : f.departments()) {
                list.add(new Entry(f.name(), d.name(), fold(d.name()), fold(f.name())));
            }
        }
        this.entries = List.copyOf(list);
        this.gradeIds = catalog.grades().stream().map(Grade::id).collect(Collectors.toUnmodifiableSet());
    }

    private static Catalog load(String path) {
        try (InputStream in = new ClassPathResource(path).getInputStream()) {
            return JsonMapper.builder().build().readValue(in, Catalog.class);
        } catch (IOException | RuntimeException e) {
            // Katalog olmadan kayit/profil dogrulamasi calisamaz: acilista acik hata
            throw new IllegalStateException("Akademik katalog yuklenemedi: " + path, e);
        }
    }

    public Catalog catalog() {
        return catalog;
    }

    public List<String> facultyNames() {
        return catalog.faculties().stream().map(Faculty::name).toList();
    }

    public boolean isValidFaculty(String faculty) {
        return faculty != null && catalog.faculties().stream().anyMatch(f -> f.name().equals(faculty));
    }

    public boolean isValidGrade(String grade) {
        return grade != null && gradeIds.contains(grade);
    }

    /** Fakulte ve bolum katalogda birlikte varsa true. */
    public boolean isValid(String faculty, String department) {
        if (faculty == null || department == null) {
            return false;
        }
        return catalog.faculties().stream().filter(f -> f.name().equals(faculty))
                .anyMatch(f -> f.departments().stream().anyMatch(d -> d.name().equals(department)));
    }

    /**
     * Yazma aninda dogrulama: null/bos alan "verilmedi" sayilir. Bolum fakulte olmadan, fakulte katalog
     * disindaysa, bolum fakultesine ait degilse veya sinif listede yoksa 400 ACADEMIC_INVALID.
     */
    public void requireValid(String faculty, String department, String grade) {
        boolean ok = (faculty == null || isValidFaculty(faculty))
                && (department == null || (faculty != null && isValid(faculty, department)))
                && (grade == null || isValidGrade(grade));
        if (!ok) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "ACADEMIC_INVALID",
                    "Fakülte, bölüm veya sınıf bilgisi geçersiz.");
        }
    }

    /** Bolum adinda (oncelikli) veya fakulte adinda aksan/buyuk-kucuk harf duyarsiz arama. */
    public List<DepartmentHit> search(String q, int limit) {
        String needle = fold(q == null ? "" : q).trim();
        int max = Math.max(1, Math.min(limit, 30));
        if (needle.isEmpty()) {
            return List.of();
        }
        return entries.stream()
                .map(e -> new Object[]{e, score(e, needle)})
                .filter(p -> (int) p[1] > 0)
                .sorted(Comparator.comparingInt((Object[] p) -> -(int) p[1])
                        .thenComparing(p -> ((Entry) p[0]).department()))
                .limit(max)
                .map(p -> new DepartmentHit(((Entry) p[0]).faculty(), ((Entry) p[0]).department()))
                .toList();
    }

    private static int score(Entry e, String needle) {
        if (e.foldedDepartment().startsWith(needle)) {
            return 4;
        }
        if (e.foldedDepartment().contains(" " + needle) || e.foldedDepartment().contains("-" + needle)) {
            return 3;
        }
        if (e.foldedDepartment().contains(needle)) {
            return 2;
        }
        return e.foldedFaculty().contains(needle) ? 1 : 0;
    }

    /** Turkce i/I/İ/ı esitlenir, aksanlar atilir, kucuk harfe cevrilir. */
    static String fold(String s) {
        String t = s.replace('İ', 'i').replace('I', 'i').replace('ı', 'i');
        t = Normalizer.normalize(t.toLowerCase(Locale.ROOT), Normalizer.Form.NFD);
        return t.replaceAll("\\p{M}+", "").replace('ß', 's');
    }
}
