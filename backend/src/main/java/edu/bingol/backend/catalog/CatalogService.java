package edu.bingol.backend.catalog;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.i18n.Lang;
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

/**
 * Akademik katalog (fakulte/bolum/sinif): acilista classpath JSON'undan yuklenir, bellekte tutulur.
 * Kanonik anahtar Turkce {@code name}'dir (DB'de saklanan/eslestirilen deger); {@code nameEn}/{@code nameAr}
 * yalniz GOSTERIM icindir, eksikse Turkceye duser.
 */
@Service
public class CatalogService {

    private static final Logger log = LoggerFactory.getLogger(CatalogService.class);
    static final String RESOURCE = "catalog/academic.json";

    public record Department(String id, String name, String nameEn, String nameAr) {
        public Department {
            nameEn = orName(nameEn, name);
            nameAr = orName(nameAr, name);
        }

        public String name(Lang lang) {
            return pick(lang, name, nameEn, nameAr);
        }
    }

    public record Faculty(String id, String name, String nameEn, String nameAr, List<Department> departments) {
        public Faculty {
            nameEn = orName(nameEn, name);
            nameAr = orName(nameAr, name);
        }

        public String name(Lang lang) {
            return pick(lang, name, nameEn, nameAr);
        }
    }

    public record Grade(String id, String name, String nameEn, String nameAr) {
        public Grade {
            nameEn = orName(nameEn, name);
            nameAr = orName(nameAr, name);
        }

        public String name(Lang lang) {
            return pick(lang, name, nameEn, nameAr);
        }
    }

    public record Catalog(int version, List<Faculty> faculties, List<Grade> grades) {}

    public record DepartmentHit(String faculty, String department, String facultyEn, String facultyAr,
                                String departmentEn, String departmentAr) {}

    private record Entry(Faculty f, Department d, String foldedDepartment, String foldedFaculty,
                         String foldedDeptEn, String foldedDeptAr, String foldedFacEn, String foldedFacAr) {}

    private static String orName(String translated, String name) {
        return translated == null || translated.isBlank() ? name : translated;
    }

    private static String pick(Lang lang, String tr, String en, String ar) {
        return lang == Lang.EN ? en : lang == Lang.AR ? ar : tr;
    }

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
                list.add(new Entry(f, d, fold(d.name()), fold(f.name()), fold(d.nameEn()), fold(d.nameAr()),
                        fold(f.nameEn()), fold(f.nameAr())));
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

    /** Kanonik (Turkce) fakulte adinin istek dilindeki gosterim adi; katalogda yoksa girdi aynen doner. */
    public String facultyName(String canonical, Lang lang) {
        if (canonical == null || lang == null || lang == Lang.TR) {
            return canonical;
        }
        for (Faculty f : catalog.faculties()) {
            if (f.name().equals(canonical)) {
                return f.name(lang);
            }
        }
        return canonical;
    }

    /** Kanonik (Turkce) bolum adinin gosterim adi; fakulte verilirse yalniz onun bolumlerinde aranir. */
    public String departmentName(String canonical, String canonicalFaculty, Lang lang) {
        if (canonical == null || lang == null || lang == Lang.TR) {
            return canonical;
        }
        String found = null;
        for (Faculty f : catalog.faculties()) {
            boolean sameFaculty = canonicalFaculty != null && f.name().equals(canonicalFaculty);
            for (Department d : f.departments()) {
                if (d.name().equals(canonical)) {
                    if (sameFaculty) {
                        return d.name(lang);
                    }
                    if (found == null) {
                        found = d.name(lang);
                    }
                }
            }
        }
        return found != null ? found : canonical;
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
                        .thenComparing(p -> ((Entry) p[0]).d().name()))
                .limit(max)
                .map(p -> hit((Entry) p[0]))
                .toList();
    }

    private static DepartmentHit hit(Entry e) {
        return new DepartmentHit(e.f().name(), e.d().name(), e.f().nameEn(), e.f().nameAr(), e.d().nameEn(),
                e.d().nameAr());
    }

    /** Turkce, Ingilizce ve Arapca adlarin hepsinde arar; Turkce ad onceliklidir. */
    private static int score(Entry e, String needle) {
        int best = Math.max(deptScore(e.foldedDepartment(), needle),
                Math.max(deptScore(e.foldedDeptEn(), needle), deptScore(e.foldedDeptAr(), needle)));
        if (best > 0) {
            return best;
        }
        return e.foldedFaculty().contains(needle) || e.foldedFacEn().contains(needle)
                || e.foldedFacAr().contains(needle) ? 1 : 0;
    }

    private static int deptScore(String folded, String needle) {
        if (folded.startsWith(needle)) {
            return 4;
        }
        if (folded.contains(" " + needle) || folded.contains("-" + needle)) {
            return 3;
        }
        return folded.contains(needle) ? 2 : 0;
    }

    /** Turkce i/I/İ/ı esitlenir, aksanlar atilir, kucuk harfe cevrilir. */
    static String fold(String s) {
        String t = s.replace('İ', 'i').replace('I', 'i').replace('ı', 'i');
        t = Normalizer.normalize(t.toLowerCase(Locale.ROOT), Normalizer.Form.NFD);
        return t.replaceAll("\\p{M}+", "").replace('ß', 's');
    }
}
